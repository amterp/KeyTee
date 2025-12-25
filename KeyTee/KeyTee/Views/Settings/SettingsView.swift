//
//  SettingsView.swift
//  KeyTee
//
//  Settings window UI.
//

import SwiftUI

/// Main settings view with tabs for different setting categories.
struct SettingsView: View {
    @Bindable var settingsStore: SettingsStore

    var body: some View {
        TabView {
            GeneralSettingsView(settingsStore: settingsStore)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            StorageSettingsView(settingsStore: settingsStore)
                .tabItem {
                    Label("Storage", systemImage: "externaldrive")
                }

            AboutView(settingsStore: settingsStore)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 500, minHeight: 450)
        .frame(idealWidth: 520, idealHeight: 500)
    }
}

/// General settings: retention, timeout, launch at login
struct GeneralSettingsView: View {
    @Bindable var settingsStore: SettingsStore
    @State private var showSavedFeedback = false

    var body: some View {
        Form {
            Section {
                // Retention period
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keep captured text for")
                        .fontWeight(.medium)

                    CompoundDurationPicker(
                        hours: $settingsStore.retentionHours,
                        minutes: $settingsStore.retentionMinutes,
                        showSavedFeedback: $showSavedFeedback,
                        presets: [
                            (1, 0, "1h"),
                            (6, 0, "6h"),
                            (12, 0, "12h"),
                            (24, 0, "24h"),
                            (48, 0, "2d"),
                            (168, 0, "1w"),
                        ],
                        hoursRange: 0...720,
                        minutesRange: 0...59
                    )

                    Text("Captured text older than this is automatically and permanently deleted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Inactivity timeout
                VStack(alignment: .leading, spacing: 8) {
                    Text("New segment after")
                        .fontWeight(.medium)

                    SecondsDurationPicker(
                        seconds: $settingsStore.inactivityTimeoutSeconds,
                        showSavedFeedback: $showSavedFeedback,
                        presets: [
                            (10, "10s"),
                            (30, "30s"),
                            (60, "1m"),
                            (120, "2m"),
                            (300, "5m"),
                            (600, "10m"),
                        ],
                        range: 5...3600
                    )

                    Text("A **segment** is a chunk of continuous typing. When you stop typing for this long, KeyTee starts a new segment. This keeps separate typing sessions organized (e.g., morning vs. afternoon work).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Label("Capture", systemImage: "keyboard")
            }

            Section {
                Toggle("Launch KeyTee at login", isOn: $settingsStore.launchAtLogin)
                    .help("Automatically start KeyTee when you log in to your Mac. Recommended to ensure you never lose text.")
            } header: {
                Label("Startup", systemImage: "power")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .overlay(alignment: .top) {
            if showSavedFeedback {
                SavedFeedbackBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSavedFeedback)
    }
}

/// Saved feedback banner that appears briefly
struct SavedFeedbackBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Saved")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

/// Compound duration picker with hours + minutes fields
struct CompoundDurationPicker: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var showSavedFeedback: Bool
    let presets: [(Int, Int, String)]  // (hours, minutes, label)
    let hoursRange: ClosedRange<Int>
    let minutesRange: ClosedRange<Int>

    @FocusState private var hoursFieldFocused: Bool
    @FocusState private var minutesFieldFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            // Preset buttons
            ForEach(presets, id: \.2) { preset in
                let isSelected = hours == preset.0 && minutes == preset.1
                Button {
                    hours = preset.0
                    minutes = preset.1
                    triggerSavedFeedback()
                } label: {
                    Text(preset.2)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            isSelected
                                ? Color.accentColor.opacity(0.2)
                                : Color.secondary.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .foregroundStyle(isSelected ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Manual input fields
            DurationField(
                value: $hours,
                isFocused: $hoursFieldFocused,
                suffix: "hrs",
                range: hoursRange,
                onCommit: triggerSavedFeedback
            )

            DurationField(
                value: $minutes,
                isFocused: $minutesFieldFocused,
                suffix: "min",
                range: minutesRange,
                onCommit: triggerSavedFeedback
            )
        }
    }

    private func triggerSavedFeedback() {
        hoursFieldFocused = false
        minutesFieldFocused = false
        showSavedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSavedFeedback = false
        }
    }
}

/// Duration picker for seconds-based values (shows minutes + seconds input)
struct SecondsDurationPicker: View {
    @Binding var seconds: Int
    @Binding var showSavedFeedback: Bool
    let presets: [(Int, String)]  // (seconds, label)
    let range: ClosedRange<Int>

    @FocusState private var minutesFieldFocused: Bool
    @FocusState private var secondsFieldFocused: Bool

    // Computed minutes/seconds from total seconds
    private var displayMinutes: Int {
        seconds / 60
    }

    private var displaySeconds: Int {
        seconds % 60
    }

    var body: some View {
        HStack(spacing: 6) {
            // Preset buttons
            ForEach(presets, id: \.0) { preset in
                let isSelected = seconds == preset.0
                Button {
                    seconds = preset.0
                    triggerSavedFeedback()
                } label: {
                    Text(preset.1)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            isSelected
                                ? Color.accentColor.opacity(0.2)
                                : Color.secondary.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .foregroundStyle(isSelected ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Manual input fields (minutes + seconds)
            DurationField(
                value: Binding(
                    get: { displayMinutes },
                    set: { newMinutes in
                        let totalSeconds = (newMinutes * 60) + displaySeconds
                        seconds = min(max(totalSeconds, range.lowerBound), range.upperBound)
                    }
                ),
                isFocused: $minutesFieldFocused,
                suffix: "min",
                range: 0...60,
                onCommit: triggerSavedFeedback
            )

            DurationField(
                value: Binding(
                    get: { displaySeconds },
                    set: { newSeconds in
                        let totalSeconds = (displayMinutes * 60) + newSeconds
                        seconds = min(max(totalSeconds, range.lowerBound), range.upperBound)
                    }
                ),
                isFocused: $secondsFieldFocused,
                suffix: "sec",
                range: 0...59,
                onCommit: triggerSavedFeedback
            )
        }
    }

    private func triggerSavedFeedback() {
        minutesFieldFocused = false
        secondsFieldFocused = false
        showSavedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSavedFeedback = false
        }
    }
}

/// Individual duration input field with suffix label
struct DurationField: View {
    @Binding var value: Int
    var isFocused: FocusState<Bool>.Binding
    let suffix: String
    let range: ClosedRange<Int>
    let onCommit: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            TextField("", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 56)
                .multilineTextAlignment(.trailing)
                .focused(isFocused)
                .onSubmit {
                    clampValue()
                    onCommit()
                }
                .onChange(of: isFocused.wrappedValue) { wasFocused, nowFocused in
                    // When losing focus, clamp and trigger save
                    if wasFocused && !nowFocused {
                        clampValue()
                        onCommit()
                    }
                }

            Text(suffix)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
        }
    }

    private func clampValue() {
        if value < range.lowerBound {
            value = range.lowerBound
        } else if value > range.upperBound {
            value = range.upperBound
        }
    }
}

/// Storage settings: persistence toggle
struct StorageSettingsView: View {
    @Bindable var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Enable disk persistence", isOn: $settingsStore.persistenceEnabled)
                    .help("When enabled, captured text is encrypted and saved to disk, surviving app restarts and system reboots.")

                if settingsStore.persistenceEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(
                            icon: "lock.shield",
                            title: "Encrypted storage",
                            description: "Text is encrypted with AES-256 before saving"
                        )

                        FeatureRow(
                            icon: "key",
                            title: "Keychain-protected",
                            description: "Encryption key stored securely in macOS Keychain"
                        )

                        FeatureRow(
                            icon: "arrow.clockwise",
                            title: "Survives restarts",
                            description: "Your captured text persists through app quit and system restart"
                        )

                        FeatureRow(
                            icon: "clock",
                            title: "Same retention rules",
                            description: "Old data is still automatically deleted per your retention setting"
                        )
                    }
                    .padding(.top, 8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text("Memory-only mode")
                                .fontWeight(.medium)
                        } icon: {
                            Image(systemName: "memorychip")
                                .foregroundStyle(.blue)
                        }

                        Text("Captured text is stored in memory only. When KeyTee quits or your Mac restarts, all captured text is lost. This is the most private option.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Label("Persistence", systemImage: "externaldrive")
            } footer: {
                if settingsStore.persistenceEnabled {
                    Label("Disk persistence is not yet implemented", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Config file location")
                        .fontWeight(.medium)

                    HStack {
                        Text(settingsStore.configFilePath)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)

                        Spacer()

                        Button {
                            NSWorkspace.shared.selectFile(
                                settingsStore.configFilePath,
                                inFileViewerRootedAtPath: ""
                            )
                        } label: {
                            Label("Reveal", systemImage: "folder")
                        }
                        .help("Show config file in Finder")
                    }

                    Text("You can edit this file directly. Changes take effect on next launch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Configuration", systemImage: "doc.text")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

/// A feature row for the storage settings
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// About view with app info and reset option
struct AboutView: View {
    @Bindable var settingsStore: SettingsStore
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon and info
            VStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("KeyTee")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Version 0.1.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("A safety net for your keystrokes")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Links and actions
            VStack(spacing: 12) {
                Divider()

                HStack(spacing: 20) {
                    Link(destination: URL(string: "https://github.com/amterp/keytee")!) {
                        Label("GitHub", systemImage: "link")
                    }

                    Button("Reset All Settings") {
                        showResetConfirmation = true
                    }
                    .foregroundStyle(.red)
                }
                .font(.subheadline)
            }
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "Reset all settings to defaults?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                settingsStore.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all settings to their default values. Your captured text will not be affected.")
        }
    }
}

#Preview {
    SettingsView(settingsStore: SettingsStore())
}
