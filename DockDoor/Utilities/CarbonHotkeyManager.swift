import Carbon
import Cocoa
import Defaults

// Global callback function for Carbon hotkey - called directly on main thread
// This is the KEY to instant response - no async dispatch needed
private var carbonHotkeyCallback: ((Int, Bool) -> Void)?

/// Carbon-based hotkey manager for instant hotkey response
/// Uses RegisterEventHotKey which delivers events directly on main thread
class CarbonHotkeyManager {
    static let shared = CarbonHotkeyManager()

    // Carbon signature for DockDoor
    private static let signature: OSType = "dock".utf16.reduce(0) { ($0 << 8) + OSType($1) }

    // Event target - GetEventDispatcherTarget delivers to main event loop
    private static let shortcutEventTarget = GetEventDispatcherTarget()

    // Hotkey references
    private static var primaryHotkeyRef: EventHotKeyRef?
    private static var alternateHotkeyRef: EventHotKeyRef?

    // Event handlers
    private static var hotKeyPressedEventHandler: EventHandlerRef?
    private static var hotKeyReleasedEventHandler: EventHandlerRef?

    // Hotkey IDs
    enum HotkeyID: Int {
        case primary = 1
        case alternate = 2
    }

    private init() {}

    // MARK: - Public API

    func setup(callback: @escaping (Int, Bool) -> Void) {
        carbonHotkeyCallback = callback
        Self.addGlobalHandlerIfNeeded()
        Self.registerHotkeys()
        Self.updateNativeHotkeyState()
    }

    func cleanup() {
        Self.unregisterHotkeys()
        Self.removeHandlers()
        carbonHotkeyCallback = nil
        // Re-enable native Command+Tab on cleanup
        setNativeCommandTabEnabled(true)
    }

    func updateHotkeys() {
        Self.unregisterHotkeys()
        Self.registerHotkeys()
        Self.updateNativeHotkeyState()
    }

    // MARK: - Event Handlers

    private static func addGlobalHandlerIfNeeded() {
        // Install pressed handler
        if hotKeyPressedEventHandler == nil {
            var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))]
            let status = InstallEventHandler(shortcutEventTarget, { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                // Call directly on main thread - no async!
                carbonHotkeyCallback?(Int(id.id), true)
                return noErr
            }, eventTypes.count, &eventTypes, nil, &hotKeyPressedEventHandler)
            _ = status // Silence unused variable warning
        }

        // Install released handler
        if hotKeyReleasedEventHandler == nil {
            var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyReleased))]
            let status = InstallEventHandler(shortcutEventTarget, { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                carbonHotkeyCallback?(Int(id.id), false)
                return noErr
            }, eventTypes.count, &eventTypes, nil, &hotKeyReleasedEventHandler)
            _ = status // Silence unused variable warning
        }
    }

    private static func removeHandlers() {
        if let handler = hotKeyPressedEventHandler {
            RemoveEventHandler(handler)
            hotKeyPressedEventHandler = nil
        }
        if let handler = hotKeyReleasedEventHandler {
            RemoveEventHandler(handler)
            hotKeyReleasedEventHandler = nil
        }
    }

    // MARK: - Hotkey Registration

    private static func registerHotkeys() {
        let userKeybind = Defaults[.UserKeybind]

        // Register primary hotkey
        if userKeybind.keyCode != 0 {
            let hotkeyId = EventHotKeyID(signature: signature, id: UInt32(HotkeyID.primary.rawValue))
            let keyCode = UInt32(userKeybind.keyCode)
            let mods = carbonModifiers(from: userKeybind.modifierFlags)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(keyCode, mods, hotkeyId, shortcutEventTarget, UInt32(kEventHotKeyNoOptions), &ref)
            if status == noErr {
                primaryHotkeyRef = ref
            }
        }

        // Register alternate hotkey
        let alternateKey = Defaults[.alternateKeybindKey]
        if alternateKey != 0 {
            let hotkeyId = EventHotKeyID(signature: signature, id: UInt32(HotkeyID.alternate.rawValue))
            let keyCode = UInt32(alternateKey)
            let mods = carbonModifiers(from: userKeybind.modifierFlags)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(keyCode, mods, hotkeyId, shortcutEventTarget, UInt32(kEventHotKeyNoOptions), &ref)
            if status == noErr {
                alternateHotkeyRef = ref
            }
        }
    }

    private static func unregisterHotkeys() {
        if let ref = primaryHotkeyRef {
            UnregisterEventHotKey(ref)
            primaryHotkeyRef = nil
        }
        if let ref = alternateHotkeyRef {
            UnregisterEventHotKey(ref)
            alternateHotkeyRef = nil
        }
    }

    // MARK: - Helpers

    private static func carbonModifiers(from flags: Int) -> UInt32 {
        var carbonMods: UInt32 = 0
        if flags & Int(CGEventFlags.maskCommand.rawValue) != 0 { carbonMods |= UInt32(cmdKey) }
        if flags & Int(CGEventFlags.maskAlternate.rawValue) != 0 { carbonMods |= UInt32(optionKey) }
        if flags & Int(CGEventFlags.maskControl.rawValue) != 0 { carbonMods |= UInt32(controlKey) }
        if flags & Int(CGEventFlags.maskShift.rawValue) != 0 { carbonMods |= UInt32(shiftKey) }
        return carbonMods
    }

    /// Disable/enable native system hotkeys that overlap with our registered hotkeys
    private static func updateNativeHotkeyState() {
        let userKeybind = Defaults[.UserKeybind]
        let keyCode = userKeybind.keyCode
        let mods = carbonModifiers(from: userKeybind.modifierFlags)

        // Check if primary hotkey is Command+Tab
        let isCommandTab = (keyCode == UInt16(kVK_Tab)) && (mods == UInt32(cmdKey))
        // Check if primary hotkey is Command+Shift+Tab
        let isCommandShiftTab = (keyCode == UInt16(kVK_Tab)) && (mods == UInt32(cmdKey | shiftKey))
        // Check if primary hotkey is Command+` (key above tab)
        let isCommandGrave = (keyCode == UInt16(kVK_ANSI_Grave)) && (mods == UInt32(cmdKey))

        // Disable overlapping native hotkeys, enable non-overlapping ones
        var hotkeysToDisable: [CGSSymbolicHotKey] = []
        var hotkeysToEnable: [CGSSymbolicHotKey] = []

        if isCommandTab {
            hotkeysToDisable.append(.commandTab)
            hotkeysToDisable.append(.commandShiftTab) // Also disable Cmd+Shift+Tab to avoid confusion
        } else {
            hotkeysToEnable.append(.commandTab)
        }

        if isCommandShiftTab {
            hotkeysToDisable.append(.commandShiftTab)
        } else if !isCommandTab { // Don't re-enable if Cmd+Tab disabled it
            hotkeysToEnable.append(.commandShiftTab)
        }

        if isCommandGrave {
            hotkeysToDisable.append(.commandKeyAboveTab)
        } else {
            hotkeysToEnable.append(.commandKeyAboveTab)
        }

        // Apply changes
        for hotkey in hotkeysToDisable {
            setNativeCommandTabEnabled(false, [hotkey])
        }
        for hotkey in hotkeysToEnable {
            setNativeCommandTabEnabled(true, [hotkey])
        }
    }
}
