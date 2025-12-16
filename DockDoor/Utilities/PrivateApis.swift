import Cocoa

// Borrows from: https://github.com/lwouis/alt-tab-macos/blob/master/src/api-wrappers/private-apis/SkyLight.framework.swift

// MARK: - Type Definitions

typealias CGSConnectionID = UInt32
typealias CGSWindowCount = UInt32
typealias CGSSpaceID = UInt64

typealias ScreenUuid = CFString

// MARK: - Global Connection

let CGS_CONNECTION = CGSMainConnectionID()

// MARK: - Window Capture Options

struct CGSWindowCaptureOptions: OptionSet {
    let rawValue: UInt32
    static let ignoreGlobalClipShape = CGSWindowCaptureOptions(rawValue: 1 << 11)
    static let nominalResolution = CGSWindowCaptureOptions(rawValue: 1 << 9)
    static let bestResolution = CGSWindowCaptureOptions(rawValue: 1 << 8)
    static let fullSize = CGSWindowCaptureOptions(rawValue: 1 << 19)
}

// MARK: - Window List Options (for invisible/minimized windows)

struct CGSCopyWindowsOptions: OptionSet {
    let rawValue: Int
    static let invisible1 = CGSCopyWindowsOptions(rawValue: 1 << 0)
    static let screenSaverLevel1000 = CGSCopyWindowsOptions(rawValue: 1 << 1)
    static let invisible2 = CGSCopyWindowsOptions(rawValue: 1 << 2)
    static let unknown1 = CGSCopyWindowsOptions(rawValue: 1 << 3)
    static let unknown2 = CGSCopyWindowsOptions(rawValue: 1 << 4)
    static let desktopIconWindowLevel = CGSCopyWindowsOptions(rawValue: 1 << 5)
}

struct CGSCopyWindowsTags: OptionSet {
    let rawValue: Int
    static let level0 = CGSCopyWindowsTags(rawValue: 1 << 0)
    static let noTitleMaybePopups = CGSCopyWindowsTags(rawValue: 1 << 1)
    static let unknown1 = CGSCopyWindowsTags(rawValue: 1 << 2)
    static let mainMenuAndDesktopIcon = CGSCopyWindowsTags(rawValue: 1 << 3)
    static let unknown2 = CGSCopyWindowsTags(rawValue: 1 << 4)
}

// MARK: - Space Enums

enum CGSSpaceMask: Int {
    case current = 5
    case other = 6
    case all = 7
}

enum CGSSpaceType: Int {
    case user = 0
    case system = 2
    case fullscreen = 4
}

enum CGSWindowOrderingMode: Int {
    case orderAbove = 1
    case orderBelow = -1
    case orderOut = 0
}

// MARK: - Symbolic HotKeys

enum CGSSymbolicHotKey: Int, CaseIterable {
    case commandTab = 1
    case commandShiftTab = 2
    case commandKeyAboveTab = 6
}

// MARK: - AX Attributes

let kAXFullscreenAttribute = "AXFullScreen"

// MARK: - Process Serial Number

struct ProcessSerialNumber {
    var highLongOfPSN: UInt32 = 0
    var lowLongOfPSN: UInt32 = 0
}

enum SLPSMode: UInt32 {
    case allWindows = 0x100
    case userGenerated = 0x200
    case noWindows = 0x400
}

// MARK: - Core Connection API

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

// MARK: - AXUIElement Private APIs

@_silgen_name("_AXUIElementGetWindow") @discardableResult
func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ wid: inout CGWindowID) -> AXError

@_silgen_name("_AXUIElementCreateWithRemoteToken")
func _AXUIElementCreateWithRemoteToken(_ token: CFData) -> Unmanaged<AXUIElement>?

// MARK: - CoreDock APIs

@_silgen_name("CoreDockGetOrientationAndPinning")
func CoreDockGetOrientationAndPinning(_ outOrientation: UnsafeMutablePointer<Int32>, _ outPinning: UnsafeMutablePointer<Int32>)

@_silgen_name("CoreDockSetAutoHideEnabled")
func CoreDockSetAutoHideEnabled(_ flag: Bool)

@_silgen_name("CoreDockGetAutoHideEnabled")
func CoreDockGetAutoHideEnabled() -> Bool

@_silgen_name("CoreDockIsMagnificationEnabled")
func CoreDockIsMagnificationEnabled() -> Bool

// MARK: - Window Capture APIs

@_silgen_name("CGSHWCaptureWindowList")
func CGSHWCaptureWindowList(
    _ cid: CGSConnectionID,
    _ windowList: UnsafePointer<UInt32>,
    _ count: CGSWindowCount,
    _ options: CGSWindowCaptureOptions
) -> CFArray?

// MARK: - Window List APIs (including invisible/minimized)

@_silgen_name("CGSCopyWindowsWithOptionsAndTags")
func CGSCopyWindowsWithOptionsAndTags(
    _ cid: CGSConnectionID,
    _ owner: Int,
    _ spaces: CFArray,
    _ options: Int,
    _ setTags: UnsafeMutablePointer<Int>,
    _ clearTags: UnsafeMutablePointer<Int>
) -> CFArray

// MARK: - Window Property APIs

@_silgen_name("CGSGetWindowLevel") @discardableResult
func CGSGetWindowLevel(
    _ cid: CGSConnectionID,
    _ wid: CGWindowID,
    _ level: UnsafeMutablePointer<CGWindowLevel>
) -> CGError

@_silgen_name("CGSCopyWindowProperty") @discardableResult
func CGSCopyWindowProperty(
    _ cid: CGSConnectionID,
    _ wid: CGWindowID,
    _ property: CFString,
    _ value: UnsafeMutablePointer<CFTypeRef?>
) -> CGError

@_silgen_name("CGSGetWindowBounds") @discardableResult
func CGSGetWindowBounds(
    _ cid: CGSConnectionID,
    _ wid: UnsafeMutablePointer<CGWindowID>,
    _ frame: UnsafeMutablePointer<CGRect>
) -> CGError

@_silgen_name("CGSGetWindowOwner") @discardableResult
func CGSGetWindowOwner(
    _ cid: CGSConnectionID,
    _ wid: CGWindowID,
    _ windowCid: UnsafeMutablePointer<CGSConnectionID>
) -> CGError

@_silgen_name("CGSGetConnectionPSN") @discardableResult
func CGSGetConnectionPSN(
    _ cid: CGSConnectionID,
    _ psn: UnsafeMutablePointer<ProcessSerialNumber>
) -> CGError

@_silgen_name("CGSOrderWindow") @discardableResult
func CGSOrderWindow(
    _ cid: CGSConnectionID,
    _ wid: CGWindowID,
    _ place: CGSWindowOrderingMode.RawValue,
    _ relativeToWid: CGWindowID
) -> OSStatus

// MARK: - Space APIs

@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> CFArray

@_silgen_name("CGSManagedDisplayGetCurrentSpace")
func CGSManagedDisplayGetCurrentSpace(_ cid: CGSConnectionID, _ displayUuid: ScreenUuid) -> CGSSpaceID

@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(
    _ cid: CGSConnectionID,
    _ mask: CGSSpaceMask.RawValue,
    _ wids: CFArray
) -> CFArray

@_silgen_name("CGSSpaceGetType")
func CGSSpaceGetType(_ cid: CGSConnectionID, _ sid: CGSSpaceID) -> CGSSpaceType

@_silgen_name("CGSAddWindowsToSpaces")
func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)

@_silgen_name("CGSRemoveWindowsFromSpaces")
func CGSRemoveWindowsFromSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)

@_silgen_name("CGSMoveWindowsToManagedSpace")
func CGSMoveWindowsToManagedSpace(_ cid: CGSConnectionID, _ windows: NSArray, _ space: CGSSpaceID)

@_silgen_name("CGSManagedDisplaySetCurrentSpace")
func CGSManagedDisplaySetCurrentSpace(_ cid: CGSConnectionID, _ display: CFString, _ sid: CGSSpaceID)

@_silgen_name("CGSShowSpaces")
func CGSShowSpaces(_ cid: CGSConnectionID, _ sids: NSArray)

@_silgen_name("CGSHideSpaces")
func CGSHideSpaces(_ cid: CGSConnectionID, _ sids: NSArray)

// MARK: - Display APIs

@_silgen_name("CGSCopyActiveMenuBarDisplayIdentifier")
func CGSCopyActiveMenuBarDisplayIdentifier(_ cid: CGSConnectionID) -> ScreenUuid

@_silgen_name("SLSManagedDisplayIsAnimating")
func SLSManagedDisplayIsAnimating(_ cid: CGSConnectionID, _ displayUuid: ScreenUuid) -> Bool

// MARK: - Symbolic HotKey APIs

@_silgen_name("CGSSetSymbolicHotKeyEnabled") @discardableResult
func CGSSetSymbolicHotKeyEnabled(_ hotKey: CGSSymbolicHotKey.RawValue, _ isEnabled: Bool) -> CGError

@_silgen_name("CGSGetSymbolicHotKeyValue")
func CGSGetSymbolicHotKeyValue(
    _ hotKey: Int,
    _ options: UnsafeMutablePointer<UInt32>,
    _ keyCode: UnsafeMutablePointer<UInt32>,
    _ modifiers: UnsafeMutablePointer<UInt32>
) -> CGError

@_silgen_name("CGSIsSymbolicHotKeyEnabled")
func CGSIsSymbolicHotKeyEnabled(_ hotKey: Int) -> Bool

// MARK: - Screen Recording Access

@_silgen_name("SLSRequestScreenCaptureAccess") @discardableResult
func SLSRequestScreenCaptureAccess() -> UInt8

// MARK: - Process APIs

@_silgen_name("GetProcessForPID")
func GetProcessForPID(_ pid: pid_t, _ psn: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

@_silgen_name("GetProcessPID")
func GetProcessPID(_ psn: UnsafeMutablePointer<ProcessSerialNumber>, _ pid: UnsafeMutablePointer<pid_t>)

@_silgen_name("SameProcess")
func SameProcess(
    _ psn1: UnsafeMutablePointer<ProcessSerialNumber>,
    _ psn2: UnsafeMutablePointer<ProcessSerialNumber>,
    _ same: UnsafeMutablePointer<DarwinBoolean>
)

@_silgen_name("_SLPSGetFrontProcess") @discardableResult
func _SLPSGetFrontProcess(_ psn: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

// MARK: - SkyLight Function Loading (Dynamic)

typealias SLPSSetFrontProcessWithOptionsType = @convention(c) (
    UnsafeMutableRawPointer,
    CGWindowID,
    UInt32
) -> CGError

typealias SLPSPostEventRecordToType = @convention(c) (
    UnsafeMutableRawPointer,
    UnsafeMutablePointer<UInt8>
) -> CGError

private var skyLightHandle: UnsafeMutableRawPointer?
private var setFrontProcessPtr: SLPSSetFrontProcessWithOptionsType?
private var postEventRecordPtr: SLPSPostEventRecordToType?

private func loadSkyLightFunctions() {
    guard skyLightHandle == nil else { return }

    let skyLightPath = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
    guard let handle = dlopen(skyLightPath, RTLD_LAZY) else {
        print("Failed to load SkyLight framework")
        return
    }

    skyLightHandle = handle

    if let symbol = dlsym(handle, "_SLPSSetFrontProcessWithOptions") {
        setFrontProcessPtr = unsafeBitCast(symbol, to: SLPSSetFrontProcessWithOptionsType.self)
    }

    if let symbol = dlsym(handle, "SLPSPostEventRecordTo") {
        postEventRecordPtr = unsafeBitCast(symbol, to: SLPSPostEventRecordToType.self)
    }
}

func _SLPSSetFrontProcessWithOptions(_ psn: UnsafeMutablePointer<ProcessSerialNumber>, _ wid: CGWindowID, _ mode: SLPSMode.RawValue) -> CGError {
    loadSkyLightFunctions()
    guard let fn = setFrontProcessPtr else { return CGError(rawValue: -1)! }
    return fn(psn, wid, mode)
}

func SLPSPostEventRecordTo(_ psn: UnsafeMutablePointer<ProcessSerialNumber>, _ bytes: UnsafeMutablePointer<UInt8>) -> CGError {
    loadSkyLightFunctions()
    guard let fn = postEventRecordPtr else { return CGError(rawValue: -1)! }
    return fn(psn, bytes)
}

// MARK: - Helper Functions

func setNativeCommandTabEnabled(_ isEnabled: Bool, _ hotkeys: [CGSSymbolicHotKey] = CGSSymbolicHotKey.allCases) {
    for hotkey in hotkeys {
        CGSSetSymbolicHotKeyEnabled(hotkey.rawValue, isEnabled)
    }
}

func windowIdToPsn(_ wid: CGWindowID) -> ProcessSerialNumber {
    var elementConnection = CGSConnectionID(0)
    CGSGetWindowOwner(CGS_CONNECTION, wid, &elementConnection)
    var psn = ProcessSerialNumber()
    CGSGetConnectionPSN(elementConnection, &psn)
    return psn
}

func psnEqual(_ psn1: ProcessSerialNumber, _ psn2: ProcessSerialNumber) -> Bool {
    var psn1_ = psn1
    var psn2_ = psn2
    var same = DarwinBoolean(false)
    SameProcess(&psn1_, &psn2_, &same)
    return same == DarwinBoolean(true)
}

func windowManagerDeferWindowRaise(_ psn: ProcessSerialNumber, _ wid: CGWindowID) {
    var wid_ = wid
    var psn_ = psn
    var bytes = [UInt8](repeating: 0, count: 0xF8)
    bytes[0x04] = 0xF8
    bytes[0x08] = 0x0D
    bytes[0x8A] = 0x09
    memcpy(&bytes[0x3C], &wid_, MemoryLayout<UInt32>.size)
    _ = bytes.withUnsafeMutableBufferPointer { buffer in
        SLPSPostEventRecordTo(&psn_, buffer.baseAddress!)
    }
}

func windowManagerActivateWindow(_ psn: ProcessSerialNumber, _ wid: CGWindowID) {
    var wid_ = wid
    var psn_ = psn
    var bytes = [UInt8](repeating: 0, count: 0xF8)
    bytes[0x04] = 0xF8
    bytes[0x08] = 0x0D
    bytes[0x8A] = 0x01
    memcpy(&bytes[0x3C], &wid_, MemoryLayout<UInt32>.size)
    _ = bytes.withUnsafeMutableBufferPointer { buffer in
        SLPSPostEventRecordTo(&psn_, buffer.baseAddress!)
    }
}

func windowManagerDeactivateWindow(_ psn: ProcessSerialNumber, _ wid: CGWindowID) {
    var wid_ = wid
    var psn_ = psn
    var bytes = [UInt8](repeating: 0, count: 0xF8)
    bytes[0x04] = 0xF8
    bytes[0x08] = 0x0D
    bytes[0x8A] = 0x02
    memcpy(&bytes[0x3C], &wid_, MemoryLayout<UInt32>.size)
    _ = bytes.withUnsafeMutableBufferPointer { buffer in
        SLPSPostEventRecordTo(&psn_, buffer.baseAddress!)
    }
}
