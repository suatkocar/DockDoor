import Cocoa
import Defaults

// Base struct for window image sizing calculations
enum WindowImageSizingCalculations {
    // Alt-tab-macos thumbnailSize logic
    static func calculateThumbnailSize(imageSize: CGSize, isWindowlessApp: Bool, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        let imageWidth = imageSize.width
        let imageHeight = imageSize.height

        // Don't stretch very small windows
        if !isWindowlessApp, imageWidth < maxWidth, imageHeight < maxHeight {
            return imageSize
        }

        let thumbnailHeight = min(imageHeight, maxHeight)
        let thumbnailWidth = min(imageWidth, maxWidth)
        let imageRatio = imageWidth / imageHeight
        let thumbnailRatio = thumbnailWidth / thumbnailHeight

        var width: CGFloat
        var height: CGFloat

        if thumbnailRatio > imageRatio {
            width = imageWidth * thumbnailHeight / imageHeight
            height = thumbnailHeight
        } else if thumbnailRatio < imageRatio {
            width = thumbnailWidth
            height = imageHeight * thumbnailWidth / imageWidth
        } else {
            width = maxHeight / imageHeight * imageWidth
            height = maxHeight
        }

        return CGSize(width: width.rounded(), height: height.rounded())
    }

    // Performance optimization: caches
    private static var overallMaxDimensionsCache: CGPoint?
    private static var cachedWindowCount: Int = 0
    private static var cachedPanelSize: CGSize = .zero

    private static var precomputeCache: [Int: WindowDimensions]?
    private static var cachedPrecomputeWindowsHash: Int = 0
    private static var cachedPrecomputeMaxDimensions: CGPoint = .zero
    private static var cachedPrecomputeSwitcherActive: Bool = false

    private static func resetAllCaches() {
        overallMaxDimensionsCache = nil
        cachedWindowCount = 0
        cachedPanelSize = .zero
        precomputeCache = nil
        cachedPrecomputeWindowsHash = 0
        cachedPrecomputeMaxDimensions = .zero
        cachedPrecomputeSwitcherActive = false
    }
}

// Holds logic related to precomputing image thumbnail sizes
extension WindowImageSizingCalculations {
    private static func resetCache() {
        resetAllCaches()
    }

    struct WindowDimensions {
        let size: CGSize
        let maxDimensions: CGSize
    }

    static func calculateOverallMaxDimensions(
        windows: [WindowInfo],
        dockPosition: DockPosition,
        isWindowSwitcherActive: Bool,
        isMockPreviewActive: Bool,
        sharedPanelWindowSize: CGSize
    ) -> CGPoint {
        // Cache validation
        let isFirstRun = overallMaxDimensionsCache == nil
        let windowsChanged = windows.count != cachedWindowCount
        let sizeChanged = sharedPanelWindowSize != cachedPanelSize

        if !isFirstRun, !windowsChanged, !sizeChanged, let cached = overallMaxDimensionsCache {
            return cached
        }

        cachedWindowCount = windows.count
        cachedPanelSize = sharedPanelWindowSize

        if Defaults[.allowDynamicImageSizing] {
            let thickness = max(WindowManagementConstants.minPreviewThickness,
                                min(WindowManagementConstants.maxPreviewThickness, Defaults[.previewHeight]))
            var maxWidth: CGFloat = WindowManagementConstants.defaultPreviewMaxWidth
            var maxHeight: CGFloat = WindowManagementConstants.defaultPreviewMaxHeight
            let orientationIsHorizontal = dockPosition == .bottom || dockPosition == .cmdTab || isWindowSwitcherActive
            let maxAspectRatio: CGFloat = WindowManagementConstants.maxPreviewAspectRatio

            if !windows.isEmpty {
                for window in windows {
                    if let cgImage = window.image {
                        let cgSize = CGSize(width: cgImage.width, height: cgImage.height)
                        if orientationIsHorizontal {
                            let widthBasedOnHeight = min((cgSize.width * thickness) / cgSize.height, thickness * maxAspectRatio)
                            maxWidth = max(maxWidth, widthBasedOnHeight)
                            maxHeight = thickness
                        } else {
                            let heightBasedOnWidth = min((cgSize.height * thickness) / cgSize.width, thickness * maxAspectRatio)
                            maxHeight = max(maxHeight, heightBasedOnWidth)
                            maxWidth = thickness
                        }
                    } else {
                        // Windowless apps fallback
                        if orientationIsHorizontal {
                            maxWidth = max(maxWidth, WindowManagementConstants.defaultPreviewMaxWidth)
                            maxHeight = thickness
                        } else {
                            maxWidth = thickness
                            maxHeight = max(maxHeight, WindowManagementConstants.defaultPreviewMaxHeight)
                        }
                    }
                }
            } else {
                maxWidth = thickness
                maxHeight = thickness
            }

            let result = CGPoint(x: max(1, maxWidth), y: max(1, maxHeight))
            overallMaxDimensionsCache = result
            return result
        } else {
            let result = CGPoint(x: Defaults[.previewWidth], y: Defaults[.previewHeight])
            overallMaxDimensionsCache = result
            return result
        }
    }

    static func precomputeWindowDimensions(
        windows: [WindowInfo],
        overallMaxDimensions: CGPoint,
        bestGuessMonitor: NSScreen,
        dockPosition: DockPosition,
        isWindowSwitcherActive: Bool,
        previewMaxColumns: Int,
        previewMaxRows: Int,
        switcherMaxRows: Int,
        switcherMaxColumns: Int
    ) -> [Int: WindowDimensions] {
        // Create hash for windows to detect changes
        let currentWindowsHash = windows.reduce(0) { hash, window in
            var windowHash = hash
            windowHash ^= window.app.processIdentifier.hashValue
            if let windowName = window.windowName {
                windowHash ^= windowName.hashValue
            }
            return windowHash
        }

        // Check if we can use cached results
        if let cached = precomputeCache,
           currentWindowsHash == cachedPrecomputeWindowsHash,
           overallMaxDimensions == cachedPrecomputeMaxDimensions,
           isWindowSwitcherActive == cachedPrecomputeSwitcherActive
        {
            return cached
        }

        var dimensionsMap: [Int: WindowDimensions] = [:]

        let cardMaxFrameDimensions = CGSize(
            width: bestGuessMonitor.frame.width * WindowManagementConstants.cardMaxFrameScreenPercentage,
            height: bestGuessMonitor.frame.height * WindowManagementConstants.cardMaxFrameScreenPercentage
        )

        if Defaults[.allowDynamicImageSizing] {
            let orientationIsHorizontal = dockPosition == .bottom || dockPosition == .cmdTab || isWindowSwitcherActive

            let (effectiveMaxColumns, effectiveMaxRows) = calculateEffectiveMaxColumnsAndRows(
                bestGuessMonitor: bestGuessMonitor,
                overallMaxDimensions: overallMaxDimensions,
                dockPosition: dockPosition,
                isWindowSwitcherActive: isWindowSwitcherActive,
                previewMaxColumns: previewMaxColumns,
                previewMaxRows: previewMaxRows,
                switcherMaxRows: switcherMaxRows,
                switcherMaxColumns: switcherMaxColumns,
                totalItems: windows.count
            )

            // Use bin-packing for horizontal layouts to maximize space utilization
            let windowChunks: [[Int]]
            if orientationIsHorizontal {
                let thickness = overallMaxDimensions.y
                let screenWidth = bestGuessMonitor.frame.width * Defaults[.layoutWidthPercentage]
                let itemSpacing: CGFloat = 24
                let globalPadding: CGFloat = 40
                let maxRowWidth = screenWidth - globalPadding

                windowChunks = createBinPackedChunks(
                    windows: windows,
                    maxRowWidth: maxRowWidth,
                    thickness: thickness,
                    itemSpacing: itemSpacing,
                    maxColumns: effectiveMaxColumns,
                    maxRows: effectiveMaxRows
                )
            } else {
                // For vertical layouts, use traditional chunking
                windowChunks = createWindowChunks(
                    totalWindows: windows.count,
                    isHorizontal: orientationIsHorizontal,
                    maxColumns: effectiveMaxColumns,
                    maxRows: effectiveMaxRows
                )
            }

            for (_, chunk) in windowChunks.enumerated() {
                var unifiedHeight: CGFloat = 0
                var unifiedWidth: CGFloat = 0

                if orientationIsHorizontal {
                    let thickness = overallMaxDimensions.y
                    for windowIndex in chunk {
                        guard windowIndex < windows.count else { continue }
                        let windowInfo = windows[windowIndex]

                        guard let cgImage = windowInfo.image else {
                            continue
                        }

                        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
                        let aspectRatio = originalSize.width / originalSize.height

                        let rawWidthAtThickness = thickness * aspectRatio
                        let widthAtThickness = min(rawWidthAtThickness, thickness * 1.5)

                        // For low aspect ratio apps like Slack (aspectRatio < 1.0),
                        // don't force them to be as wide as high aspect ratio apps
                        let finalWidth = aspectRatio < 1.0 ?
                            min(rawWidthAtThickness, thickness * 1.2) : widthAtThickness

                        if aspectRatio < 1.0 {}

                        unifiedWidth = max(unifiedWidth, finalWidth)
                    }
                    unifiedHeight = thickness
                } else {
                    let thickness = overallMaxDimensions.x
                    for windowIndex in chunk {
                        guard windowIndex < windows.count else { continue }
                        let windowInfo = windows[windowIndex]

                        guard let cgImage = windowInfo.image else {
                            continue
                        }

                        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
                        let aspectRatio = originalSize.width / originalSize.height

                        let rawWidthAtThickness = thickness * aspectRatio
                        let widthAtThickness = min(rawWidthAtThickness, thickness * 1.5)

                        unifiedWidth = max(unifiedWidth, widthAtThickness)
                    }
                    unifiedWidth = thickness
                }

                for windowIndex in chunk {
                    guard windowIndex < windows.count else { continue }
                    let windowInfo = windows[windowIndex]

                    if windowInfo.image != nil {
                        // Alt-tab-macos thumbnailSize logic - birebir aynı
                        let cgImage = windowInfo.image!
                        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
                        let isWindowlessApp = windowInfo.windowProvider.windowID == 0 // Windowless apps have windowID 0

                        let windowSize = WindowImageSizingCalculations.calculateThumbnailSize(
                            imageSize: originalSize,
                            isWindowlessApp: isWindowlessApp,
                            maxWidth: unifiedWidth,
                            maxHeight: unifiedHeight
                        )

                        dimensionsMap[windowIndex] = WindowDimensions(
                            size: windowSize,
                            maxDimensions: cardMaxFrameDimensions
                        )
                    } else {
                        // Windowless apps and windows without images use fallback with proper aspect ratio
                        let fallbackWidth = min(300, overallMaxDimensions.x)
                        let fallbackHeight = min(300, overallMaxDimensions.y)
                        let fallbackSize = CGSize(width: fallbackWidth, height: fallbackHeight)
                        dimensionsMap[windowIndex] = WindowDimensions(
                            size: fallbackSize,
                            maxDimensions: cardMaxFrameDimensions
                        )
                    }
                }
            }
        } else {
            let width = Defaults[.previewWidth]
            let height = Defaults[.previewHeight]

            for (index, _) in windows.enumerated() {
                dimensionsMap[index] = WindowDimensions(
                    size: CGSize(width: width, height: height),
                    maxDimensions: cardMaxFrameDimensions
                )
            }
        }

        // Update cache
        precomputeCache = dimensionsMap
        cachedPrecomputeWindowsHash = currentWindowsHash
        cachedPrecomputeMaxDimensions = overallMaxDimensions
        cachedPrecomputeSwitcherActive = isWindowSwitcherActive

        return dimensionsMap
    }

    static func calculateSingleWindowDimensions(
        windowInfo: WindowInfo,
        overallMaxDimensions: CGPoint,
        bestGuessMonitor: NSScreen
    ) -> WindowDimensions {
        let width = Defaults[.previewWidth]
        let height = Defaults[.previewHeight]
        let fixedBoxSize = CGSize(width: width, height: height)

        let cardMaxFrameDimensions = CGSize(
            width: bestGuessMonitor.frame.width * 0.75,
            height: bestGuessMonitor.frame.height * 0.75
        )

        return WindowDimensions(
            size: fixedBoxSize,
            maxDimensions: cardMaxFrameDimensions
        )
    }

    // MARK: - Helper Functions

    /// Calculates the effective maximum columns and rows based on screen size and user settings
    /// - Parameters:
    ///   - bestGuessMonitor: The screen to calculate for
    ///   - overallMaxDimensions: The maximum preview dimensions (width and height)
    ///   - dockPosition: Current dock position
    ///   - isWindowSwitcherActive: Whether window switcher is active
    ///   - previewMaxColumns: User setting for max columns
    ///   - previewMaxRows: User setting for max rows
    ///   - switcherMaxRows: Max rows for window switcher
    ///   - totalItems: Total number of items to display
    /// - Returns: Tuple of (maxColumns, maxRows)
    static func calculateEffectiveMaxColumnsAndRows(
        bestGuessMonitor: NSScreen,
        overallMaxDimensions: CGPoint,
        dockPosition: DockPosition,
        isWindowSwitcherActive: Bool,
        previewMaxColumns: Int,
        previewMaxRows: Int,
        switcherMaxRows: Int,
        switcherMaxColumns: Int,
        totalItems: Int? = nil
    ) -> (maxColumns: Int, maxRows: Int) {
        let screenWidth = bestGuessMonitor.frame.width * Defaults[.layoutWidthPercentage]
        let screenHeight = bestGuessMonitor.frame.height * 0.80
        let itemSpacing: CGFloat = 24
        let globalPadding: CGFloat = 40

        let previewWidth = overallMaxDimensions.x
        let previewHeight = overallMaxDimensions.y

        let calculatedMaxColumns = max(1, Int((screenWidth - globalPadding + itemSpacing) / (previewWidth + itemSpacing)))
        let calculatedMaxRows = max(1, Int((screenHeight - globalPadding + itemSpacing) / (previewHeight + itemSpacing)))

        var effectiveMaxColumns: Int
        var effectiveMaxRows: Int

        if isWindowSwitcherActive {
            // For window switcher, use user's column setting directly
            // Bin-packing will handle fitting windows within screen width
            effectiveMaxColumns = switcherMaxColumns
            effectiveMaxRows = switcherMaxRows
        } else if dockPosition == .bottom || dockPosition == .cmdTab {
            effectiveMaxColumns = calculatedMaxColumns
            effectiveMaxRows = (dockPosition == .cmdTab) ? 1 : previewMaxRows
        } else {
            effectiveMaxColumns = previewMaxColumns
            effectiveMaxRows = calculatedMaxRows
        }

        let result = (effectiveMaxColumns, effectiveMaxRows)
        return result
    }

    /// Organizes items into rows/columns based on flow direction
    /// - Parameters:
    ///   - items: Array of items to chunk
    ///   - isHorizontal: If true, fills rows left-to-right; if false, fills columns top-to-bottom
    ///   - maxColumns: Maximum items per row or maximum columns
    ///   - maxRows: Maximum rows or maximum items per column
    ///   - reverse: If true, reverses layout based on direction of window preview
    /// - Returns: Array of chunks (rows or columns)
    static func chunkArray<T>(
        items: [T],
        isHorizontal: Bool,
        maxColumns: Int,
        maxRows: Int,
        reverse: Bool = false
    ) -> [[T]] {
        let totalItems = items.count

        guard totalItems > 0, maxColumns > 0, maxRows > 0 else {
            return []
        }

        var chunks: [[T]]

        if isHorizontal {
            // Fill rows up to maxColumns, then create new rows
            // This ensures 9 items with maxColumns=5 becomes 5+4, not 3+3+3
            let itemsPerRow = maxColumns

            chunks = []
            var startIndex = 0
            var rowIndex = 0

            while startIndex < totalItems {
                let endIndex = min(startIndex + itemsPerRow, totalItems)
                let rowItems = Array(items[startIndex ..< endIndex])

                if !rowItems.isEmpty {
                    chunks.append(rowItems)
                }

                startIndex = endIndex
                rowIndex += 1
            }
        } else {
            // Fill columns up to maxRows, then create new columns
            let itemsPerColumn = maxRows

            chunks = []
            var startIndex = 0
            var columnIndex = 0

            while startIndex < totalItems {
                let endIndex = min(startIndex + itemsPerColumn, totalItems)
                let columnItems = Array(items[startIndex ..< endIndex])

                if !columnItems.isEmpty {
                    chunks.append(columnItems)
                }

                startIndex = endIndex
                columnIndex += 1
            }
        }

        if reverse {
            chunks = chunks.reversed()
        }

        return chunks
    }

    /// Creates chunks of window indices organized by rows/columns based on flow direction
    private static func createWindowChunks(
        totalWindows: Int,
        isHorizontal: Bool,
        maxColumns: Int,
        maxRows: Int
    ) -> [[Int]] {
        let windowIndices = Array(0 ..< totalWindows)
        return chunkArray(
            items: windowIndices,
            isHorizontal: isHorizontal,
            maxColumns: maxColumns,
            maxRows: maxRows
        )
    }

    // MARK: - Bin-Packing Layout

    /// Calculates the estimated width of a window preview based on its aspect ratio
    /// - Parameters:
    ///   - window: The window to calculate width for
    ///   - thickness: The fixed height (thickness) for horizontal layout
    ///   - maxPreviewWidth: Maximum preview width from user settings (optional)
    /// - Returns: Estimated width of the window preview
    private static func estimateWindowWidth(for window: WindowInfo, thickness: CGFloat, maxPreviewWidth: CGFloat? = nil) -> CGFloat {
        // Use user's preview width setting as upper bound if provided
        let userMaxWidth = maxPreviewWidth ?? CGFloat(Defaults[.previewWidth])

        guard let cgImage = window.image else {
            // Default width for windowless apps or missing images
            return min(thickness * 0.8, userMaxWidth)
        }

        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
        let aspectRatio = originalSize.width / originalSize.height

        // Calculate width based on aspect ratio
        let rawWidthAtThickness = thickness * aspectRatio
        let widthAtThickness = min(rawWidthAtThickness, thickness * 1.5)

        // For low aspect ratio apps (like Slack), use narrower width
        var finalWidth = aspectRatio < 1.0 ?
            min(rawWidthAtThickness, thickness * 1.2) : widthAtThickness

        // Respect user's preview width setting as maximum
        finalWidth = min(finalWidth, userMaxWidth)

        return finalWidth
    }

    /// Creates bin-packed chunks of window indices based on actual window widths
    /// Windows are placed in rows to maximize space utilization
    /// - Parameters:
    ///   - windows: Array of windows to pack
    ///   - maxRowWidth: Maximum width available for each row
    ///   - thickness: The fixed height (thickness) for horizontal layout
    ///   - itemSpacing: Spacing between items
    ///   - maxColumns: Maximum items per row (user setting, ignored if useWidthBasedLayout is true)
    ///   - maxRows: Maximum rows allowed
    /// - Returns: Array of chunks (rows) with window indices
    static func createBinPackedChunks(
        windows: [WindowInfo],
        maxRowWidth: CGFloat,
        thickness: CGFloat,
        itemSpacing: CGFloat = 24,
        maxColumns: Int,
        maxRows: Int
    ) -> [[Int]] {
        guard !windows.isEmpty else { return [] }

        // Check if width-based layout is enabled (ignores column limits entirely)
        let useWidthBasedLayout = Defaults[.useWidthBasedLayout]

        // Calculate widths for all windows
        let windowWidths: [(index: Int, width: CGFloat)] = windows.enumerated().map { index, window in
            (index, estimateWindowWidth(for: window, thickness: thickness))
        }

        var chunks: [[Int]] = []
        var currentRow: [Int] = []
        var currentRowWidth: CGFloat = 0
        var currentRowCount = 0

        for (index, width) in windowWidths {
            let widthWithSpacing = currentRow.isEmpty ? width : width + itemSpacing

            // Check if this window fits in current row physically
            let fitsInRow = currentRowWidth + widthWithSpacing <= maxRowWidth

            // Determine if we should add to current row
            let shouldAddToRow: Bool
            if useWidthBasedLayout {
                // WIDTH-BASED LAYOUT: Only check physical fit, ignore column limit entirely
                // Windows fill the row until there's no more physical space
                shouldAddToRow = fitsInRow
            } else {
                // COLUMN-BASED LAYOUT: Respect maxColumns but allow smart overflow
                let underMaxColumns = currentRowCount < maxColumns
                let canOverflowIfSpaceAvailable = fitsInRow && currentRowCount >= maxColumns
                let remainingSpaceRatio = (maxRowWidth - currentRowWidth) / maxRowWidth
                let hasSignificantSpace = remainingSpaceRatio > 0.15
                shouldAddToRow = fitsInRow && (underMaxColumns || (canOverflowIfSpaceAvailable && hasSignificantSpace))
            }

            if shouldAddToRow {
                // Add to current row
                currentRow.append(index)
                currentRowWidth += widthWithSpacing
                currentRowCount += 1
            } else {
                // Start new row
                if !currentRow.isEmpty {
                    chunks.append(currentRow)
                }

                // Check if we've hit max rows
                if chunks.count >= maxRows {
                    // Add remaining windows to last row anyway
                    currentRow = [index]
                    for remaining in windowWidths.dropFirst(index + 1) {
                        currentRow.append(remaining.index)
                    }
                    chunks[chunks.count - 1].append(contentsOf: currentRow.dropFirst())
                    return chunks
                }

                currentRow = [index]
                currentRowWidth = width
                currentRowCount = 1
            }
        }

        // Don't forget the last row
        if !currentRow.isEmpty {
            chunks.append(currentRow)
        }

        return chunks
    }

    /// Navigates window switcher grid
    /// - Returns: New index after navigation
    static func navigateWindowSwitcher(
        from currentIndex: Int,
        direction: ArrowDirection,
        totalItems: Int,
        dockPosition: DockPosition,
        isWindowSwitcherActive: Bool
    ) -> Int {
        guard let coordinator = SharedPreviewWindowCoordinator.activeInstance?.windowSwitcherCoordinator else {
            let delta = (direction == .right || direction == .down) ? 1 : -1
            return (currentIndex + delta + totalItems) % totalItems
        }

        let bestGuessMonitor = NSScreen.main ?? NSScreen.screens.first!
        let isHorizontalFlow = dockPosition.isHorizontalFlow || isWindowSwitcherActive

        let (maxColumns, maxRows) = calculateEffectiveMaxColumnsAndRows(
            bestGuessMonitor: bestGuessMonitor,
            overallMaxDimensions: coordinator.overallMaxPreviewDimension,
            dockPosition: dockPosition,
            isWindowSwitcherActive: isWindowSwitcherActive,
            previewMaxColumns: Defaults[.previewMaxColumns],
            previewMaxRows: Defaults[.previewMaxRows],
            switcherMaxRows: Defaults[.switcherMaxRows],
            switcherMaxColumns: Defaults[.switcherMaxColumns],
            totalItems: totalItems
        )

        let shouldReverse = (dockPosition == .bottom || dockPosition == .right) && !isWindowSwitcherActive

        return navigateInGrid(
            from: currentIndex,
            direction: direction,
            totalItems: totalItems,
            isHorizontal: isHorizontalFlow,
            maxColumns: maxColumns,
            maxRows: maxRows,
            reverse: shouldReverse
        )
    }

    /// Navigates in a 2D grid
    /// - Returns: New flat index after navigation
    static func navigateInGrid(
        from currentIndex: Int,
        direction: ArrowDirection,
        totalItems: Int,
        isHorizontal: Bool,
        maxColumns: Int,
        maxRows: Int,
        reverse: Bool = false
    ) -> Int {
        guard totalItems > 0, currentIndex >= 0, currentIndex < totalItems else {
            return currentIndex
        }

        let items = Array(0 ..< totalItems)
        let chunks = chunkArray(items: items, isHorizontal: isHorizontal, maxColumns: maxColumns, maxRows: maxRows, reverse: reverse)

        var currentChunkIndex = 0
        var currentPositionInChunk = 0

        for (chunkIdx, chunk) in chunks.enumerated() {
            if let posInChunk = chunk.firstIndex(of: currentIndex) {
                currentChunkIndex = chunkIdx
                currentPositionInChunk = posInChunk
                break
            }
        }

        var targetChunkIndex = currentChunkIndex
        var targetPositionInChunk = currentPositionInChunk

        if isHorizontal {
            switch direction {
            case .left:
                targetPositionInChunk -= 1
                if targetPositionInChunk < 0 {
                    targetChunkIndex = (currentChunkIndex - 1 + chunks.count) % chunks.count
                    targetPositionInChunk = chunks[targetChunkIndex].count - 1
                }
            case .right:
                targetPositionInChunk += 1
                if targetPositionInChunk >= chunks[currentChunkIndex].count {
                    targetChunkIndex = (currentChunkIndex + 1) % chunks.count
                    targetPositionInChunk = 0
                }
            case .up:
                targetChunkIndex = (currentChunkIndex - 1 + chunks.count) % chunks.count
                targetPositionInChunk = min(currentPositionInChunk, chunks[targetChunkIndex].count - 1)
            case .down:
                targetChunkIndex = (currentChunkIndex + 1) % chunks.count
                targetPositionInChunk = min(currentPositionInChunk, chunks[targetChunkIndex].count - 1)
            }
        } else {
            switch direction {
            case .up:
                targetPositionInChunk -= 1
                if targetPositionInChunk < 0 {
                    targetChunkIndex = (currentChunkIndex - 1 + chunks.count) % chunks.count
                    targetPositionInChunk = chunks[targetChunkIndex].count - 1
                }
            case .down:
                targetPositionInChunk += 1
                if targetPositionInChunk >= chunks[currentChunkIndex].count {
                    targetChunkIndex = (currentChunkIndex + 1) % chunks.count
                    targetPositionInChunk = 0
                }
            case .left:
                targetChunkIndex = (currentChunkIndex - 1 + chunks.count) % chunks.count
                targetPositionInChunk = min(currentPositionInChunk, chunks[targetChunkIndex].count - 1)
            case .right:
                targetChunkIndex = (currentChunkIndex + 1) % chunks.count
                targetPositionInChunk = min(currentPositionInChunk, chunks[targetChunkIndex].count - 1)
            }
        }

        return chunks[targetChunkIndex][targetPositionInChunk]
    }
}
