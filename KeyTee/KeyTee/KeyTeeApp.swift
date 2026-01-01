//
//  KeyTeeApp.swift
//  KeyTee
//
//  Created by amterp on 2025-12-25.
//

import SwiftUI

/// KeyTee is a menu bar app that captures keystrokes as a safety net for recovering lost text.
///
/// Architecture notes for Swift newcomers:
/// - `@main` marks this as the app's entry point
/// - `@NSApplicationDelegateAdaptor` bridges SwiftUI with AppKit's NSApplicationDelegate,
///   giving us lifecycle hooks (applicationDidFinishLaunching, etc.)
/// - `MenuBarExtra` (macOS 13+) creates a menu bar item with a dropdown menu
/// - We use `Window` with an ID to create a window that can be opened programmatically
@main
struct KeyTeeApp: App {
    // Bridge to AppDelegate for lifecycle events and service initialization
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Global app state - shared across all views
    @State private var appState = AppState()

    /// Menu bar icon varies by build type and pause state.
    /// Debug builds use filled icons for visual distinction.
    private var menuBarIconName: String {
        #if DEBUG
        appState.isPaused ? "keyboard.badge.ellipsis.fill" : "keyboard.fill"
        #else
        appState.isPaused ? "keyboard.badge.ellipsis" : "keyboard"
        #endif
    }

    /// Window title includes "Dev" suffix in debug builds.
    private var windowTitle: String {
        #if DEBUG
        "KeyTee Dev"
        #else
        "KeyTee"
        #endif
    }

    var body: some Scene {
        // Menu bar icon and dropdown menu
        MenuBarExtra {
            MenuDropdownView(appState: appState)
        } label: {
            // Note: The label renders immediately at app launch (unlike the dropdown content),
            // so we use .task here to run startup logic as soon as the menu bar icon appears.
            Image(systemName: menuBarIconName)
                .task {
                    appState.checkOnboarding()
                    if appState.accessibilityChecker.isAccessibilityEnabled &&
                       appState.hasCompletedOnboarding {
                        appState.startCaptureIfAllowed()
                    }
                }
        }

        // Main window showing captured text history
        // This window is opened programmatically when user clicks "Open KeyTee" in menu
        Window(windowTitle, id: "main") {
            MainWindowView(appState: appState)
                .sheet(isPresented: $appState.showOnboarding) {
                    OnboardingView(accessibilityChecker: appState.accessibilityChecker) {
                        appState.completeOnboarding()
                    }
                }
        }

        // Settings window (opened via Settings menu item or Cmd+,)
        Settings {
            SettingsView(settingsStore: appState.settingsStore)
        }
    }

}

/// The dropdown menu that appears when clicking the menu bar icon.
///
/// SwiftUI's `MenuBarExtra` content is rendered as a standard macOS menu,
/// so we use `Button` for menu items rather than custom views.
struct MenuDropdownView: View {
    // App state for pause toggle
    @Bindable var appState: AppState

    // Access the app environment to open windows programmatically
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Open the main window to view captured text
        Button("Open KeyTee") {
            openWindow(id: "main")
            // Bring our app to the front when opening the window
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o")

        Divider()

        // Toggle keystroke capture on/off
        Button(appState.isPaused ? "Resume Capture" : "Pause Capture") {
            appState.togglePause()
        }
        .keyboardShortcut("p")

        Divider()

        // Open settings window
        SettingsLink {
            Text("Settings...")
        }
        .keyboardShortcut(",")

        Divider()

        // Quit the app
        Button("Quit KeyTee") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
