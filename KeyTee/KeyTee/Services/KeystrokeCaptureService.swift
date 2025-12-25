//
//  KeystrokeCaptureService.swift
//  KeyTee
//
//  System-wide keystroke capture using CGEventTap.
//

import Carbon
import AppKit
import CoreGraphics

/// Captures keystrokes system-wide using a CGEventTap.
///
/// How CGEventTap works:
/// - It's a low-level mechanism to intercept input events before they reach apps
/// - We create a "passive" tap that observes events without modifying them
/// - The tap is registered with the system's event stream
/// - A callback function is invoked for each matching event
///
/// Why CGEventTap over AXObserver:
/// - CGEventTap provides system-wide capture with a single hook
/// - AXObserver would require setting up observers per-app/per-element
/// - CGEventTap is optimized for real-time input processing
///
/// Requirements:
/// - Accessibility permission must be granted (checked before starting)
/// - The callback must be fast to avoid input lag (< 1ms ideally)
class KeystrokeCaptureService {

    // MARK: - Types

    /// Events emitted by the capture service
    enum CaptureEvent {
        case text(String)           // Regular character(s) typed
        case backspace              // Delete previous character
        case newline                // Enter/Return pressed
        case paste(String)          // Cmd+V with clipboard content
    }

    /// Callback type for captured events
    typealias CaptureHandler = (CaptureEvent) -> Void

    // MARK: - Properties

    /// Handler called when text is captured
    var onCapture: CaptureHandler?

    /// Detector for password fields
    private let secureFieldDetector = SecureFieldDetector()

    /// Our app's bundle ID, to exclude self-capture
    private let ownBundleId: String

    /// The CGEventTap handle
    /// fileprivate because the global callback function needs to access it
    fileprivate var eventTap: CFMachPort?

    /// Run loop source for the event tap
    private var runLoopSource: CFRunLoopSource?

    /// Whether capture is currently active
    private(set) var isCapturing = false

    // MARK: - Initialization

    init() {
        // Get our own bundle ID to exclude from capture
        ownBundleId = Bundle.main.bundleIdentifier ?? "com.amterp.KeyTee"
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// Start capturing keystrokes.
    ///
    /// - Returns: `true` if capture started successfully, `false` if it failed
    ///   (usually due to missing Accessibility permission)
    @discardableResult
    func start() -> Bool {
        guard !isCapturing else { return true }

        // Create the event tap
        // We need to capture this service instance in the callback, but CGEventTap
        // uses a C function pointer, so we pass `self` as the userInfo and retrieve it in the callback
        let refToSelf = Unmanaged.passUnretained(self).toOpaque()

        // Event mask: we want keyDown events
        // CGEventMaskBit creates a bitmask for the specified event type
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        // Create the tap
        // - tap: .cgSessionEventTap captures events for the current user session
        // - place: .headInsertEventTap means we see events first
        // - options: .defaultTap is a passive observer (doesn't block/modify events)
        // - eventsOfInterest: our event mask
        // - callback: the C function that handles events
        // - userInfo: pointer to self for use in the callback
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: keystrokeCallback,
            userInfo: refToSelf
        ) else {
            print("KeyTee: Failed to create event tap. Is Accessibility permission granted?")
            return false
        }

        eventTap = tap

        // Create a run loop source from the tap
        // This integrates the tap with the run loop so our callback gets invoked
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        // Add to the main run loop
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)

        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)

        isCapturing = true
        print("KeyTee: Keystroke capture started")
        return true
    }

    /// Stop capturing keystrokes.
    func stop() {
        guard isCapturing else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isCapturing = false
        print("KeyTee: Keystroke capture stopped")
    }

    // MARK: - Event Processing

    /// Process a keyboard event and emit appropriate capture events.
    ///
    /// This is called from the CGEventTap callback for each keyDown event.
    fileprivate func processKeyEvent(_ event: CGEvent) {
        // Skip if the frontmost app is KeyTee itself
        if let frontApp = secureFieldDetector.getFocusedAppBundleId(),
           frontApp == ownBundleId {
            return
        }

        // Skip if a secure (password) field is focused
        if secureFieldDetector.isSecureFieldFocused() {
            return
        }

        // Get the key code and modifier flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Check for modifier keys (Cmd, Ctrl, Option)
        let hasCmd = flags.contains(.maskCommand)
        let hasCtrl = flags.contains(.maskControl)
        let hasOption = flags.contains(.maskAlternate)

        // Handle Cmd+V (paste) specially: capture clipboard content
        if hasCmd && keyCode == kVK_ANSI_V {
            handlePaste()
            return
        }

        // Skip other Cmd/Ctrl shortcuts (Cmd+C, Cmd+Z, etc.)
        // These don't produce text output
        if hasCmd || hasCtrl {
            return
        }

        // Handle special keys
        switch Int(keyCode) {
        case kVK_Delete:  // Backspace
            onCapture?(.backspace)
            return

        case kVK_Return, kVK_ANSI_KeypadEnter:  // Enter/Return
            onCapture?(.newline)
            return

        case kVK_Tab:  // Tab - capture as text
            onCapture?(.text("\t"))
            return

        case kVK_Escape,
             kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown,
             kVK_UpArrow, kVK_DownArrow, kVK_LeftArrow, kVK_RightArrow:
            // Skip navigation keys, arrows
            // We don't track cursor position, so these are meaningless to us
            return

        case kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8,
             kVK_F9, kVK_F10, kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15,
             kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20:
            // Skip function keys
            return

        default:
            break
        }

        // Convert keycode to character string
        if let characters = getCharacters(from: event, hasOption: hasOption) {
            if !characters.isEmpty {
                onCapture?(.text(characters))
            }
        }
    }

    /// Handle Cmd+V paste by reading the clipboard.
    private func handlePaste() {
        // Read the string content from the general pasteboard
        if let clipboardString = NSPasteboard.general.string(forType: .string) {
            if !clipboardString.isEmpty {
                onCapture?(.paste(clipboardString))
            }
        }
    }

    /// Convert a keyboard event to the character(s) it produces.
    ///
    /// This is complex because we need to account for:
    /// - Current keyboard layout (US, UK, German, etc.)
    /// - Modifier keys (Shift for uppercase, Option for special characters)
    /// - Dead keys (accents in some layouts)
    ///
    /// We use the Text Input Source (TIS) API to do this conversion correctly.
    private func getCharacters(from event: CGEvent, hasOption: Bool) -> String? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Get the current keyboard layout
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            // Fallback: try to get characters directly from the event
            return getCharactersFallback(from: event)
        }

        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self)
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        // Build modifier key state for UCKeyTranslate
        var modifierKeyState: UInt32 = 0
        if flags.contains(.maskShift) {
            modifierKeyState |= UInt32(shiftKey >> 8)
        }
        if flags.contains(.maskAlternate) {
            modifierKeyState |= UInt32(optionKey >> 8)
        }
        if flags.contains(.maskCommand) {
            modifierKeyState |= UInt32(cmdKey >> 8)
        }

        // Translate the key code to Unicode characters
        var deadKeyState: UInt32 = 0
        var unicodeString = [UniChar](repeating: 0, count: 4)
        var actualStringLength: Int = 0

        let status = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDown),
            modifierKeyState,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState,
            unicodeString.count,
            &actualStringLength,
            &unicodeString
        )

        guard status == noErr, actualStringLength > 0 else {
            return getCharactersFallback(from: event)
        }

        return String(utf16CodeUnits: unicodeString, count: actualStringLength)
    }

    /// Fallback method to get characters from CGEvent directly.
    ///
    /// CGEvent has a `keyboardGetUnicodeString` method, but it may not always
    /// account for the keyboard layout correctly. We use this as a fallback.
    private func getCharactersFallback(from event: CGEvent) -> String? {
        var actualStringLength: Int = 0
        var unicodeString = [UniChar](repeating: 0, count: 4)

        event.keyboardGetUnicodeString(
            maxStringLength: 4,
            actualStringLength: &actualStringLength,
            unicodeString: &unicodeString
        )

        guard actualStringLength > 0 else { return nil }

        return String(utf16CodeUnits: unicodeString, count: actualStringLength)
    }
}

// MARK: - CGEventTap Callback

/// The C-style callback function for the CGEventTap.
///
/// Why is this a global function instead of a method?
/// - CGEventTap requires a C function pointer
/// - Swift closures can't be converted to C function pointers
/// - We pass `self` through the userInfo parameter and retrieve it here
///
/// Parameters:
/// - proxy: The event tap proxy (unused, but required by the signature)
/// - type: The type of event (keyDown, keyUp, etc.)
/// - event: The actual event to process
/// - userInfo: Pointer to our KeystrokeCaptureService instance
///
/// Returns:
/// - The event unchanged (we're observing, not modifying)
private func keystrokeCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    // Handle tap disabled/re-enabled events
    // The system can temporarily disable our tap under heavy load
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        // Re-enable the tap
        if let userInfo = userInfo {
            let service = Unmanaged<KeystrokeCaptureService>.fromOpaque(userInfo).takeUnretainedValue()
            if let tap = service.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    // Only process keyDown events
    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    // Retrieve our service instance from userInfo
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let service = Unmanaged<KeystrokeCaptureService>.fromOpaque(userInfo).takeUnretainedValue()
    service.processKeyEvent(event)

    // Return the event unchanged (we're just observing)
    return Unmanaged.passUnretained(event)
}

// MARK: - Virtual Key Codes

// These constants are from Carbon's Events.h
// They represent physical key positions on the keyboard, independent of layout

private let kVK_ANSI_V: Int64 = 0x09
private let kVK_Delete: Int = 0x33          // Backspace
private let kVK_Return: Int = 0x24          // Return/Enter
private let kVK_ANSI_KeypadEnter: Int = 0x4C
private let kVK_Tab: Int = 0x30
private let kVK_Escape: Int = 0x35
private let kVK_Home: Int = 0x73
private let kVK_End: Int = 0x77
private let kVK_PageUp: Int = 0x74
private let kVK_PageDown: Int = 0x79
private let kVK_UpArrow: Int = 0x7E
private let kVK_DownArrow: Int = 0x7D
private let kVK_LeftArrow: Int = 0x7B
private let kVK_RightArrow: Int = 0x7C
private let kVK_F1: Int = 0x7A
private let kVK_F2: Int = 0x78
private let kVK_F3: Int = 0x63
private let kVK_F4: Int = 0x76
private let kVK_F5: Int = 0x60
private let kVK_F6: Int = 0x61
private let kVK_F7: Int = 0x62
private let kVK_F8: Int = 0x64
private let kVK_F9: Int = 0x65
private let kVK_F10: Int = 0x6D
private let kVK_F11: Int = 0x67
private let kVK_F12: Int = 0x6F
private let kVK_F13: Int = 0x69
private let kVK_F14: Int = 0x6B
private let kVK_F15: Int = 0x71
private let kVK_F16: Int = 0x6A
private let kVK_F17: Int = 0x40
private let kVK_F18: Int = 0x4F
private let kVK_F19: Int = 0x50
private let kVK_F20: Int = 0x5A
