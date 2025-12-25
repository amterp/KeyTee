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

    var body: some Scene {
        // Menu bar icon and dropdown menu
        MenuBarExtra {
            // StartupView runs once to initialize services
            StartupView(appState: appState)
            MenuDropdownView(appState: appState)
        } label: {
            // Show different icon when paused
            Image(systemName: appState.isPaused ? "keyboard.badge.ellipsis" : "keyboard")
        }

        // Main window showing captured text history
        // This window is opened programmatically when user clicks "Open KeyTee" in menu
        Window("KeyTee", id: "main") {
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

    init() {
        // Note: We can't pass appState to appDelegate in init because @State
        // hasn't been initialized yet. We'll handle startup in the Window's onAppear.
    }
}

/// Helper view that runs startup logic when the app launches.
/// This ensures AppState is properly initialized before we try to use it.
struct StartupView: View {
    @Bindable var appState: AppState

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                // Run startup logic once when app launches
                await startup()
            }
    }

    @MainActor
    private func startup() async {
        // Check if we need to show onboarding
        appState.checkOnboarding()

        // If permission is already granted and onboarding done, start capture
        if appState.accessibilityChecker.isAccessibilityEnabled &&
           appState.hasCompletedOnboarding {
            appState.startCaptureIfAllowed()
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
