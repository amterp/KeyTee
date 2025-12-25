//
//  OnboardingView.swift
//  KeyTee
//
//  First-launch onboarding flow for Accessibility permission.
//

import SwiftUI

/// Onboarding view shown when Accessibility permission is not granted.
///
/// This view explains why the permission is needed and guides the user
/// through enabling it in System Settings.
struct OnboardingView: View {
    /// The accessibility checker to monitor permission status
    @Bindable var accessibilityChecker: AccessibilityChecker

    /// Callback when onboarding is complete (permission granted)
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header icon
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .padding(.top, 40)

            // Title
            Text("KeyTee Needs Accessibility Access")
                .font(.title)
                .fontWeight(.semibold)

            // Explanation
            VStack(alignment: .leading, spacing: 12) {
                PermissionExplanationRow(
                    icon: "keyboard",
                    title: "Capture Keystrokes",
                    description: "KeyTee captures your typing across all apps so you can recover text if something goes wrong."
                )

                PermissionExplanationRow(
                    icon: "lock.shield",
                    title: "Privacy Protected",
                    description: "Captured text stays on your Mac. Password fields are automatically skipped."
                )

                PermissionExplanationRow(
                    icon: "clock",
                    title: "Temporary Storage",
                    description: "Text is only kept for 24 hours by default, then automatically deleted."
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Status indicator
            HStack {
                if accessibilityChecker.isAccessibilityEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Permission Granted!")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                    Text("Permission Required")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.headline)

            // Action button
            if accessibilityChecker.isAccessibilityEnabled {
                Button("Get Started") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                VStack(spacing: 12) {
                    Button("Open System Settings") {
                        accessibilityChecker.openAccessibilitySettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("Enable KeyTee in Privacy & Security → Accessibility")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
                .frame(height: 40)
        }
        .frame(width: 540, height: 520)
        .onAppear {
            // Start polling for permission changes
            accessibilityChecker.startPolling()
        }
        .onDisappear {
            accessibilityChecker.stopPolling()
        }
        .onChange(of: accessibilityChecker.isAccessibilityEnabled) { _, isEnabled in
            // Auto-complete when permission is granted
            if isEnabled {
                // Small delay to show the "granted" state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }
        }
    }
}

/// A row explaining one aspect of the permission.
struct PermissionExplanationRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)  // Allow text to wrap
            }
        }
    }
}

#Preview {
    OnboardingView(accessibilityChecker: AccessibilityChecker()) {
        print("Onboarding complete")
    }
}
