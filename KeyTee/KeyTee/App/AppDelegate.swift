//
//  AppDelegate.swift
//  KeyTee
//
//  Handles application lifecycle events and initializes core services.
//

import AppKit
import SwiftUI

/// AppDelegate bridges SwiftUI with AppKit's lifecycle system.
///
/// Why we need this:
/// - SwiftUI's `App` protocol doesn't expose all lifecycle events
/// - We need `applicationDidFinishLaunching` to start keystroke capture
/// - We need to check/request Accessibility permissions before capture works
///
/// The `@NSApplicationDelegateAdaptor` in KeyTeeApp.swift connects this to the SwiftUI app.
class AppDelegate: NSObject, NSApplicationDelegate {

    /// Shared app state - will be set by KeyTeeApp
    var appState: AppState?

    /// Called when the app has finished launching.
    /// This is where we initialize services that need to run from startup.
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("KeyTee launched")

        // Check if we need to show onboarding
        appState?.checkOnboarding()

        // If permission is already granted and onboarding done, start capture
        if appState?.accessibilityChecker.isAccessibilityEnabled == true &&
           appState?.hasCompletedOnboarding == true {
            appState?.startCaptureIfAllowed()
        }
    }

    /// Called when the app is about to terminate.
    /// Clean up resources and optionally persist state.
    func applicationWillTerminate(_ notification: Notification) {
        print("KeyTee terminating")

        // Stop keystroke capture
        appState?.captureService.stop()

        // TODO: Flush any pending data to disk (if persistence enabled)
    }

    /// Called when the app becomes active (brought to foreground).
    func applicationDidBecomeActive(_ notification: Notification) {
        // Recheck accessibility permission in case user just enabled it
        appState?.accessibilityChecker.checkAccessibility()
    }

    /// Prevent the app from terminating when the last window is closed.
    /// Menu bar apps should keep running even with no windows open.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
