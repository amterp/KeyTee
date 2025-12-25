//
//  AccessibilityChecker.swift
//  KeyTee
//
//  Checks and requests macOS Accessibility permissions.
//

import AppKit
import ApplicationServices

/// Manages Accessibility permission checking and prompting.
///
/// Why Accessibility permissions are needed:
/// - System-wide keystroke capture requires the Accessibility API
/// - macOS requires explicit user consent in System Settings
/// - Without this permission, CGEventTap won't receive keyboard events
///
/// The permission flow:
/// 1. App checks `AXIsProcessTrusted()` on launch
/// 2. If not trusted, show onboarding UI explaining the need
/// 3. User clicks button that opens System Settings → Privacy → Accessibility
/// 4. User manually enables KeyTee in the list
/// 5. App detects the change and starts capture
///
/// Note: There's no API to programmatically grant this permission—user must do it manually.
@Observable
class AccessibilityChecker {
    /// Whether the app currently has Accessibility permission
    var isAccessibilityEnabled: Bool = false

    /// Timer for polling permission status (since there's no notification for changes)
    private var pollTimer: Timer?

    init() {
        checkAccessibility()
    }

    deinit {
        stopPolling()
    }

    /// Check if the app has Accessibility permission.
    ///
    /// `AXIsProcessTrusted()` returns true if the app is in the Accessibility list
    /// and the checkbox is enabled.
    func checkAccessibility() {
        isAccessibilityEnabled = AXIsProcessTrusted()
    }

    /// Prompt the user to grant Accessibility permission.
    ///
    /// This opens System Settings to the Accessibility pane and highlights our app
    /// (if it's already in the list). The `kAXTrustedCheckOptionPrompt` key triggers
    /// the system prompt that asks "KeyTee would like to control this computer..."
    ///
    /// - Returns: `true` if already trusted, `false` if prompt was shown
    @discardableResult
    func promptForAccessibility() -> Bool {
        // This dictionary tells the system to show the permission prompt if not trusted
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        isAccessibilityEnabled = trusted
        return trusted
    }

    /// Open System Settings directly to the Accessibility Privacy pane.
    ///
    /// This is an alternative to `promptForAccessibility()` that gives users
    /// a direct path to enable the permission without the system prompt.
    func openAccessibilitySettings() {
        // The URL scheme for System Settings panes
        // "x-apple.systempreferences:" is the scheme, the path specifies the pane
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Start polling for Accessibility permission changes.
    ///
    /// Since macOS doesn't provide a notification when the user toggles the permission,
    /// we poll periodically. This is only active when permission is not yet granted.
    func startPolling() {
        guard pollTimer == nil else { return }

        // Poll every 1 second while waiting for permission
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAccessibility()

            // Stop polling once permission is granted
            if self?.isAccessibilityEnabled == true {
                self?.stopPolling()
            }
        }
    }

    /// Stop polling for permission changes.
    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
