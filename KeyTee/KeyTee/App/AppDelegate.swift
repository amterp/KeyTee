//
//  AppDelegate.swift
//  KeyTee
//
//  Handles application lifecycle events.
//

import AppKit

/// AppDelegate bridges SwiftUI with AppKit's lifecycle system.
///
/// Why we need this:
/// - Menu bar apps need `applicationShouldTerminateAfterLastWindowClosed` to return false
/// - Provides lifecycle logging for debugging
///
/// The `@NSApplicationDelegateAdaptor` in KeyTeeApp.swift connects this to the SwiftUI app.
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("KeyTee launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("KeyTee terminating")
    }

    /// Prevent the app from terminating when the last window is closed.
    /// Menu bar apps should keep running even with no windows open.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
