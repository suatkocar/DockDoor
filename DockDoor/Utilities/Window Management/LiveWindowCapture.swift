import Cocoa
import Defaults
import ScreenCaptureKit
import SwiftUI
import VideoToolbox

struct LivePreviewImage: View {
    let windowID: CGWindowID
    let fallbackImage: CGImage?
    let quality: LivePreviewQuality
    let frameRate: LivePreviewFrameRate

    @ObservedObject private var capture: WindowLiveCapture

    init(windowID: CGWindowID, fallbackImage: CGImage?, quality: LivePreviewQuality, frameRate: LivePreviewFrameRate) {
        self.windowID = windowID
        self.fallbackImage = fallbackImage
        self.quality = quality
        self.frameRate = frameRate
        capture = LiveCaptureManager.shared.getCapture(windowID: windowID, quality: quality, frameRate: frameRate)
    }

    var body: some View {
        Group {
            if let image = capture.capturedImage ?? capture.lastFrame ?? fallbackImage {
                Image(decorative: image, scale: 1.0)
                    .interpolation(.high)
                    .antialiased(true)
                    .resizable()
            }
        }
        .task {
            await capture.startCapture()
        }
    }
}

@MainActor
final class LiveCaptureManager {
    static let shared = LiveCaptureManager()
    private static let maxConcurrentStreams = 24

    private var captures: [CGWindowID: WindowLiveCapture] = [:]
    private var accessOrder: [CGWindowID] = []
    private var stopGeneration = 0

    private init() {}

    func panelOpened() {
        stopGeneration += 1
    }

    func panelClosed() async {
        let keepAlive = Defaults[.livePreviewStreamKeepAlive]

        if keepAlive < 0 {
            return
        }

        if keepAlive == 0 {
            await stopAllStreams()
            return
        }

        stopGeneration += 1
        let generationAtClose = stopGeneration

        try? await Task.sleep(nanoseconds: UInt64(keepAlive) * 1_000_000_000)

        guard stopGeneration == generationAtClose else { return }

        await stopAllStreams()
    }

    func getCapture(windowID: CGWindowID, quality: LivePreviewQuality, frameRate: LivePreviewFrameRate) -> WindowLiveCapture {
        if let existing = captures[windowID] {
            refreshAccess(windowID)
            return existing
        }

        while captures.count >= Self.maxConcurrentStreams {
            evictOldest()
        }

        let capture = WindowLiveCapture(windowID: windowID, quality: quality, frameRate: frameRate)
        captures[windowID] = capture
        accessOrder.append(windowID)
        return capture
    }

    func remove(windowID: CGWindowID) {
        captures.removeValue(forKey: windowID)
        accessOrder.removeAll { $0 == windowID }
    }

    /// Get the last captured frame for a window (useful for updating thumbnails after live preview ends)
    func getLastFrame(for windowID: CGWindowID) -> CGImage? {
        captures[windowID]?.lastFrame ?? captures[windowID]?.capturedImage
    }

    func stopAllStreams() async {
        // Stop all captures and wait for them to complete
        for capture in captures.values {
            await capture.forceStopBlocking()
        }
        captures.removeAll()
        accessOrder.removeAll()
    }

    private func refreshAccess(_ windowID: CGWindowID) {
        accessOrder.removeAll { $0 == windowID }
        accessOrder.append(windowID)
    }

    private func evictOldest() {
        guard let oldestID = accessOrder.first else { return }
        if let capture = captures.removeValue(forKey: oldestID) {
            capture.forceStopNonBlocking()
        }
        accessOrder.removeFirst()
    }
}

@MainActor
final class WindowLiveCapture: ObservableObject {
    @Published var capturedImage: CGImage?

    private let windowID: CGWindowID
    private let quality: LivePreviewQuality
    private let frameRate: LivePreviewFrameRate
    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    private var stopGeneration = 0
    private(set) var lastFrame: CGImage?

    init(windowID: CGWindowID, quality: LivePreviewQuality, frameRate: LivePreviewFrameRate) {
        self.windowID = windowID
        self.quality = quality
        self.frameRate = frameRate
    }

    private var isCancelled = false

    func startCapture() async {
        let generationAtStart = stopGeneration
        isCancelled = false
        guard stream == nil else { return }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)

            // Check if cancelled during async operation
            guard !isCancelled, stopGeneration == generationAtStart else { return }

            guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                return
            }
            await startStream(for: scWindow, generationAtStart: generationAtStart)
        } catch {
            DebugLogger.log("LiveWindowCapture: Failed to get shareable content", details: error.localizedDescription)
        }
    }

    private func startStream(for window: SCWindow, generationAtStart: Int) async {
        let filter = SCContentFilter(desktopIndependentWindow: window)

        let config = SCStreamConfiguration()

        let nativeWidth: Int
        let nativeHeight: Int
        if #available(macOS 14.0, *) {
            let pixelScale = CGFloat(filter.pointPixelScale)
            nativeWidth = Int(filter.contentRect.width * pixelScale)
            nativeHeight = Int(filter.contentRect.height * pixelScale)
        } else {
            let pixelScale = NSScreen.main?.backingScaleFactor ?? 2.0
            nativeWidth = Int(window.frame.width * pixelScale)
            nativeHeight = Int(window.frame.height * pixelScale)
        }
        let maxDim = quality.maxDimension

        if quality == .native {
            config.width = nativeWidth
            config.height = nativeHeight
            config.scalesToFit = false
        } else if quality.useFullResolution {
            var targetWidth = nativeWidth
            var targetHeight = nativeHeight

            if maxDim > 0 {
                let aspectRatio = Double(targetWidth) / Double(targetHeight)
                if targetWidth > targetHeight {
                    if targetWidth > maxDim {
                        targetWidth = maxDim
                        targetHeight = Int(Double(targetWidth) / aspectRatio)
                    }
                } else {
                    if targetHeight > maxDim {
                        targetHeight = maxDim
                        targetWidth = Int(Double(targetHeight) * aspectRatio)
                    }
                }
            }

            config.width = targetWidth
            config.height = targetHeight
            config.scalesToFit = maxDim > 0 && (nativeWidth > maxDim || nativeHeight > maxDim)
        } else {
            let aspectRatio = Double(nativeWidth) / Double(nativeHeight)
            let limitDim = maxDim > 0 ? maxDim : 640
            if aspectRatio > 1 {
                config.width = min(limitDim, nativeWidth)
                config.height = Int(Double(config.width) / aspectRatio)
            } else {
                config.height = min(limitDim, nativeHeight)
                config.width = Int(Double(config.height) * aspectRatio)
            }
            config.scalesToFit = true
        }

        config.minimumFrameInterval = CMTime(value: 1, timescale: frameRate.frameRate)
        config.showsCursor = false
        config.queueDepth = quality == .native || quality == .retina ? 5 : 3

        if #available(macOS 14.0, *) {
            config.captureResolution = .best
        }

        if #available(macOS 15.0, *) {
            config.pixelFormat = kCVPixelFormatType_ARGB2101010LEPacked
            config.captureDynamicRange = .hdrLocalDisplay
            config.colorSpaceName = CGColorSpace.displayP3 as CFString
        } else if #available(macOS 14.0, *) {
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.colorSpaceName = CGColorSpace.displayP3 as CFString
        } else {
            config.pixelFormat = kCVPixelFormatType_32BGRA
        }

        do {
            // Check if cancelled before starting stream
            guard !isCancelled, stopGeneration == generationAtStart else { return }

            let newStream = SCStream(filter: filter, configuration: config, delegate: nil)

            let output = StreamOutput { [weak self] image in
                Task { @MainActor in
                    self?.lastFrame = image
                    self?.capturedImage = image
                }
            }

            try newStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
            try await newStream.startCapture()

            // Check if cancelled during startCapture - if so, immediately stop the stream
            guard !isCancelled, stopGeneration == generationAtStart else {
                try? await newStream.stopCapture()
                return
            }

            stream = newStream
            streamOutput = output
        } catch {
            DebugLogger.log("LiveWindowCapture: Failed to start stream", details: error.localizedDescription)
        }
    }

    func requestStop() async {
        let keepAlive = Defaults[.livePreviewStreamKeepAlive]

        if keepAlive < 0 {
            return
        }

        if keepAlive == 0 {
            await stopAndCleanup()
            return
        }

        stopGeneration += 1
        let generationAtStop = stopGeneration

        try? await Task.sleep(nanoseconds: UInt64(keepAlive) * 1_000_000_000)

        guard stopGeneration == generationAtStop else { return }

        await stopAndCleanup()
    }

    func stopAndCleanup() async {
        isCancelled = true
        stopGeneration += 1
        guard let stream else { return }
        streamOutput = nil
        self.stream = nil
        capturedImage = nil
        try? await stream.stopCapture()
        LiveCaptureManager.shared.remove(windowID: windowID)
    }

    func forceStopNonBlocking() {
        isCancelled = true
        stopGeneration += 1
        guard let stream else { return }
        let streamToStop = stream
        self.stream = nil
        streamOutput = nil
        Task.detached {
            try? await streamToStop.stopCapture()
        }
    }

    /// Stops the stream and waits for completion - use when you need to ensure stream is fully stopped
    func forceStopBlocking() async {
        isCancelled = true
        stopGeneration += 1
        guard let stream else { return }
        self.stream = nil
        streamOutput = nil
        capturedImage = nil
        try? await stream.stopCapture()
    }
}

private class StreamOutput: NSObject, SCStreamOutput {
    private let onFrame: (CGImage) -> Void

    init(onFrame: @escaping (CGImage) -> Void) {
        self.onFrame = onFrame
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)

        if let image = cgImage {
            onFrame(image)
        }
    }
}
