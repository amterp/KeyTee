//
//  SettingsStore.swift
//  KeyTee
//
//  Observable settings state that syncs with the config file.
//

import Foundation
import ServiceManagement

/// Observable store for app settings.
///
/// This bridges the Config (file-based) with the UI and app behavior.
/// Changes are automatically saved to the config file.
///
/// Usage:
/// - UI binds to properties like `retentionHours`
/// - When changed, the setter saves to disk and notifies observers
/// - CaptureStore observes this to update timeouts, etc.
@Observable
class SettingsStore {

    // MARK: - Settings Properties

    /// How long to keep captured text - hours component
    var retentionHours: Int {
        didSet {
            if retentionHours != oldValue {
                saveConfig()
            }
        }
    }

    /// How long to keep captured text - minutes component
    var retentionMinutes: Int {
        didSet {
            if retentionMinutes != oldValue {
                saveConfig()
            }
        }
    }

    /// Inactivity timeout in seconds
    var inactivityTimeoutSeconds: Int {
        didSet {
            if inactivityTimeoutSeconds != oldValue {
                saveConfig()
            }
        }
    }

    /// Whether disk persistence is enabled
    var persistenceEnabled: Bool {
        didSet {
            if persistenceEnabled != oldValue {
                saveConfig()
            }
        }
    }

    /// Whether to launch at login
    var launchAtLogin: Bool {
        didSet {
            if launchAtLogin != oldValue {
                saveConfig()
                updateLaunchAtLogin()
            }
        }
    }

    // MARK: - Computed Properties

    /// Retention period in seconds (for CaptureStore)
    var retentionPeriodSeconds: TimeInterval {
        TimeInterval(retentionHours * 3600 + retentionMinutes * 60)
    }

    /// Inactivity timeout as TimeInterval (for CaptureStore)
    var inactivityTimeout: TimeInterval {
        TimeInterval(inactivityTimeoutSeconds)
    }

    /// Path to the config file (for display)
    var configFilePath: String {
        ConfigManager.shared.configPath
    }

    // MARK: - Initialization

    init() {
        // Load config from disk
        let config = ConfigManager.shared.load()

        // Initialize all properties
        self.retentionHours = config.retentionHours
        self.retentionMinutes = config.retentionMinutes
        self.inactivityTimeoutSeconds = config.inactivityTimeoutSeconds
        self.persistenceEnabled = config.persistenceEnabled
        self.launchAtLogin = config.launchAtLogin

        // Apply config's launch-at-login setting to the system
        // This ensures synced config files (via git) are respected
        applyLaunchAtLoginToSystem()
    }

    // MARK: - Methods

    /// Reload settings from disk (if externally modified)
    func reload() {
        let config = ConfigManager.shared.load()
        self.retentionHours = config.retentionHours
        self.retentionMinutes = config.retentionMinutes
        self.inactivityTimeoutSeconds = config.inactivityTimeoutSeconds
        self.persistenceEnabled = config.persistenceEnabled
        self.launchAtLogin = config.launchAtLogin
    }

    /// Reset all settings to defaults
    func resetToDefaults() {
        let config = ConfigManager.shared.reset()
        self.retentionHours = config.retentionHours
        self.retentionMinutes = config.retentionMinutes
        self.inactivityTimeoutSeconds = config.inactivityTimeoutSeconds
        self.persistenceEnabled = config.persistenceEnabled
        self.launchAtLogin = config.launchAtLogin
        updateLaunchAtLogin()
    }

    // MARK: - Private Methods

    /// Save current settings to config file
    private func saveConfig() {
        let config = Config(
            retentionHours: retentionHours,
            retentionMinutes: retentionMinutes,
            inactivityTimeoutSeconds: inactivityTimeoutSeconds,
            persistenceEnabled: persistenceEnabled,
            launchAtLogin: launchAtLogin
        )
        ConfigManager.shared.save(config)
    }

    /// Update the system launch-at-login setting
    private func updateLaunchAtLogin() {
        applyLaunchAtLoginToSystem()
    }

    /// Apply the config's launch-at-login setting to the system.
    /// This ensures that synced config files (via git dotfiles) are respected.
    private func applyLaunchAtLoginToSystem() {
        let systemStatus = SMAppService.mainApp.status
        let isCurrentlyRegistered = (systemStatus == .enabled)

        // Only make changes if needed
        if launchAtLogin && !isCurrentlyRegistered {
            do {
                try SMAppService.mainApp.register()
                print("KeyTee: Registered for launch at login")
            } catch {
                print("KeyTee: Failed to register for launch at login: \(error)")
            }
        } else if !launchAtLogin && isCurrentlyRegistered {
            do {
                try SMAppService.mainApp.unregister()
                print("KeyTee: Unregistered from launch at login")
            } catch {
                print("KeyTee: Failed to unregister from launch at login: \(error)")
            }
        }
    }
}
