//
//  SecureFieldDetector.swift
//  KeyTee
//
//  Detects whether the currently focused UI element is a secure/password field.
//

import ApplicationServices
import AppKit

/// Detects secure text fields (password inputs) to avoid capturing sensitive data.
///
/// How it works:
/// - Uses the Accessibility API to query the currently focused UI element
/// - Checks if the element has the "AXSecureTextField" role
/// - If it's a secure field, keystroke capture should be skipped
///
/// Limitations (accepted per spec):
/// - Electron/web apps may not correctly report secure field status
/// - Some non-native apps don't implement Accessibility properly
/// - We accept that some passwords may be captured; mitigation is short retention + encryption
///
/// Performance notes:
/// - This is called on every keystroke, so it must be fast
/// - AX queries are reasonably fast but not free; we cache briefly if needed
class SecureFieldDetector {

    /// The system-wide Accessibility element (represents the entire UI)
    /// We reuse this rather than creating it on every check.
    private let systemWideElement: AXUIElement

    init() {
        // AXUIElementCreateSystemWide() gives us a handle to query any app's UI
        systemWideElement = AXUIElementCreateSystemWide()
    }

    /// Check if the currently focused UI element is a secure text field.
    ///
    /// - Returns: `true` if the focused element is a password/secure field, `false` otherwise
    ///
    /// Implementation notes:
    /// - `kAXFocusedUIElementAttribute` gets the currently focused element across all apps
    /// - `kAXRoleAttribute` tells us what type of element it is (button, text field, etc.)
    /// - Secure text fields have role "AXSecureTextField" or sometimes a subrole indicating security
    func isSecureFieldFocused() -> Bool {
        // Get the currently focused element across the system
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        // If we can't get the focused element, assume it's not secure (fail open for usability)
        guard focusResult == .success, let element = focusedElement else {
            return false
        }

        // Cast to AXUIElement (the CFTypeRef is actually an AXUIElement)
        let axElement = element as! AXUIElement

        // Check the role of the focused element
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXRoleAttribute as CFString,
            &role
        )

        if roleResult == .success, let roleString = role as? String {
            // "AXSecureTextField" is the standard role for password fields
            if roleString == "AXSecureTextField" {
                return true
            }
        }

        // Also check subrole, as some apps use that for security indication
        var subrole: CFTypeRef?
        let subroleResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXSubroleAttribute as CFString,
            &subrole
        )

        if subroleResult == .success, let subroleString = subrole as? String {
            // "AXSecureTextField" can also appear as a subrole
            if subroleString == "AXSecureTextField" {
                return true
            }
        }

        return false
    }

    /// Get the bundle identifier of the app that owns the focused element.
    ///
    /// Used to exclude KeyTee itself from capture (prevent feedback loops).
    ///
    /// - Returns: The bundle ID of the focused app, or nil if unavailable
    func getFocusedAppBundleId() -> String? {
        // Get the frontmost app using NSWorkspace (more reliable than AX for this)
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
