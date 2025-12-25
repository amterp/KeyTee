//
//  AppState.swift
//  KeyTee
//
//  Global application state shared across the app.
//

import SwiftUI

/// Global application state observable by all views.
///
/// This is the central state container that holds:
/// - Services (accessibility checker, keystroke capture, window tracking)
/// - UI state (isPaused, hasCompletedOnboarding)
/// - Settings (loaded from config file)
/// - Captured text organized in CaptureStore
///
/// Using @Observable (Swift 5.9+) for efficient, automatic UI updates.
/// Views that use AppState will only re-render when properties they access change.
@Observable
class AppState {

    // MARK: - Services

    /// Checks and manages Accessibility permission
    let accessibilityChecker = AccessibilityChecker()

    /// Captures keystrokes system-wide
    let captureService = KeystrokeCaptureService()

    /// Tracks the frontmost app/window
    let windowTracker = ActiveWindowTracker()

    // MARK: - Settings & State

    /// Settings loaded from config file
    let settingsStore = SettingsStore()

    /// Central store for all captured text, organized by buckets
    let captureStore = CaptureStore()

    /// Whether keystroke capture is currently paused
    var isPaused: Bool = false {
        didSet {
            if isPaused {
                captureService.stop()
            } else if accessibilityChecker.isAccessibilityEnabled {
                captureService.start()
            }
        }
    }

    /// Whether the user has completed the onboarding flow
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    /// Whether to show the onboarding sheet
    var showOnboarding: Bool = false

    // MARK: - Initialization

    init() {
        // Sync CaptureStore with settings
        syncSettingsToCaptureStore()
        setupCaptureHandler()
    }

    /// Sync settings to CaptureStore when settings change
    private func syncSettingsToCaptureStore() {
        captureStore.inactivityTimeout = settingsStore.inactivityTimeout
        captureStore.retentionPeriod = settingsStore.retentionPeriodSeconds
    }

    // MARK: - Methods

    /// Set up the capture service event handler.
    /// Routes captured events to the CaptureStore with the current window context.
    private func setupCaptureHandler() {
        captureService.onCapture = { [weak self] event in
            guard let self = self else { return }

            // Update window context before processing
            // This ensures we have the latest app/window info
            self.windowTracker.updateCurrentContext()

            // Skip if no valid context (e.g., KeyTee is frontmost)
            guard let context = self.windowTracker.currentContext else {
                return
            }

            // Process on main thread for UI updates
            DispatchQueue.main.async {
                switch event {
                case .text(let text):
                    self.captureStore.appendText(text, to: context)
                    print("Captured in \(context.displayName): \(text)")

                case .backspace:
                    self.captureStore.handleBackspace(in: context)
                    print("Captured in \(context.displayName): [backspace]")

                case .newline:
                    self.captureStore.handleNewline(in: context)
                    print("Captured in \(context.displayName): [newline]")

                case .paste(let text):
                    self.captureStore.handlePaste(text, in: context)
                    print("Captured paste in \(context.displayName): \(text.prefix(50))...")
                }
            }
        }
    }

    /// Start keystroke capture if permission is granted
    func startCaptureIfAllowed() {
        guard accessibilityChecker.isAccessibilityEnabled else {
            print("KeyTee: Cannot start capture - Accessibility permission not granted")
            return
        }

        guard !isPaused else {
            print("KeyTee: Capture is paused")
            return
        }

        captureService.start()
    }

    /// Check if we should show onboarding
    func checkOnboarding() {
        // Show onboarding if either:
        // 1. User hasn't completed onboarding before, OR
        // 2. Accessibility permission is not granted
        if !hasCompletedOnboarding || !accessibilityChecker.isAccessibilityEnabled {
            showOnboarding = true
        }
    }

    /// Complete the onboarding flow
    func completeOnboarding() {
        hasCompletedOnboarding = true
        showOnboarding = false
        startCaptureIfAllowed()
    }

    /// Toggle pause state
    func togglePause() {
        isPaused.toggle()
    }
}
