//
//  ActiveWindowTracker.swift
//  KeyTee
//
//  Tracks the frontmost application and window for context grouping.
//

import AppKit
import CoreGraphics

/// Tracks the currently active (frontmost) application and window.
///
/// This is used to determine which bucket captured text should go into.
/// When the user switches apps or windows, we update the current context
/// so subsequent keystrokes are grouped correctly.
///
/// How it works:
/// - Uses NSWorkspace notifications to detect app switches
/// - Uses CGWindowListCopyWindowInfo to get window titles
/// - Caches the current context to avoid repeated lookups
///
/// Note: Getting window titles may not work for all apps (especially
/// without Screen Recording permission). We accept blank titles in that case.
@Observable
class ActiveWindowTracker {
    /// The currently active app/window context
    /// Updated when the frontmost app/window changes
    private(set) var currentContext: WindowContext?

    /// Our app's bundle ID, to detect when KeyTee is frontmost
    private let ownBundleId: String

    /// Observer token for workspace notifications
    private var appActivationObserver: NSObjectProtocol?

    init() {
        ownBundleId = Bundle.main.bundleIdentifier ?? "com.amterp.KeyTee"
        setupObservers()
        updateCurrentContext()
    }

    deinit {
        if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// Force an update of the current context.
    /// Called before each keystroke capture to ensure we have the latest context.
    func updateCurrentContext() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            currentContext = nil
            return
        }

        // Don't track KeyTee itself
        if frontApp.bundleIdentifier == ownBundleId {
            currentContext = nil
            return
        }

        let appName = frontApp.localizedName ?? "Unknown"
        let appBundleId = frontApp.bundleIdentifier ?? "unknown"
        let windowTitle = getWindowTitle(for: frontApp.processIdentifier) ?? ""

        // Create or update context
        // We create a new context each time because window titles can change
        currentContext = WindowContext(
            appBundleId: appBundleId,
            appName: appName,
            windowTitle: windowTitle
        )
    }

    /// Check if KeyTee is currently the frontmost app.
    var isKeyTeeFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == ownBundleId
    }

    // MARK: - Private Methods

    /// Set up observers for app activation changes.
    private func setupObservers() {
        // Watch for app switches
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
    }

    /// Handle app activation notification.
    private func handleAppActivation(_ notification: Notification) {
        updateCurrentContext()
    }

    /// Get the title of the frontmost window for a given process.
    ///
    /// Uses CGWindowListCopyWindowInfo to query window information.
    /// This works without Screen Recording permission for window titles,
    /// but some apps may still not report titles correctly.
    ///
    /// - Parameter pid: The process identifier of the app
    /// - Returns: The window title, or nil if unavailable
    private func getWindowTitle(for pid: pid_t) -> String? {
        // Get list of on-screen windows
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // Find windows belonging to the target process
        for window in windowList {
            guard let windowPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  windowPID == pid else {
                continue
            }

            // Check window layer - layer 0 is normal windows
            // (Menus, tooltips, etc. have different layers)
            guard let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                continue
            }

            // Get the window name
            if let name = window[kCGWindowName as String] as? String,
               !name.isEmpty {
                return name
            }
        }

        return nil
    }
}
