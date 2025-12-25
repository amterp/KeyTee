//
//  ConfigManager.swift
//  KeyTee
//
//  Manages reading and writing the TOML configuration file.
//

import Foundation
import TOMLKit

/// Configuration model matching the TOML file structure.
///
/// Example config file (~/.config/keytee/config.toml):
/// ```toml
/// # How long to keep captured text
/// retention_hours = 24
/// retention_minutes = 0
///
/// # Inactivity timeout before starting a new segment (in seconds)
/// inactivity_timeout_seconds = 300
///
/// # Whether to persist captured text to disk (encrypted)
/// persistence_enabled = false
///
/// # Whether to launch KeyTee at login
/// launch_at_login = true
/// ```
struct Config: Codable, Equatable {
    /// How long to keep captured text - hours component (default: 24)
    var retentionHours: Int = 24

    /// How long to keep captured text - minutes component (default: 0)
    var retentionMinutes: Int = 0

    /// Inactivity timeout in seconds before starting a new segment (default: 300 = 5 minutes)
    /// Note: Currently set to 20 for testing
    var inactivityTimeoutSeconds: Int = 20

    /// Whether to persist captured text to encrypted disk storage (default: false)
    var persistenceEnabled: Bool = false

    /// Whether to launch KeyTee automatically at login (default: true)
    var launchAtLogin: Bool = true

    /// Total retention period in seconds (computed from hours + minutes)
    var retentionTotalSeconds: Int {
        (retentionHours * 3600) + (retentionMinutes * 60)
    }

    // MARK: - Coding Keys (snake_case for TOML)

    enum CodingKeys: String, CodingKey {
        case retentionHours = "retention_hours"
        case retentionMinutes = "retention_minutes"
        case inactivityTimeoutSeconds = "inactivity_timeout_seconds"
        case persistenceEnabled = "persistence_enabled"
        case launchAtLogin = "launch_at_login"
    }
}

/// Manages the TOML configuration file at ~/.config/keytee/config.toml
///
/// Why TOML?
/// - Human-readable and easy to edit manually
/// - Less verbose than JSON, fewer quirks than YAML
/// - Friendly to version control and dotfile syncing
///
/// The config file is created with defaults if it doesn't exist.
/// Changes made in the Settings UI are written back to the file.
class ConfigManager {

    /// Shared singleton instance
    static let shared = ConfigManager()

    /// Path to the config directory
    private let configDirectory: URL

    /// Path to the config file
    private let configFilePath: URL

    /// Default config file content with comments
    private let defaultConfigContent = """
    # KeyTee Configuration
    # https://github.com/amterp/keytee

    # How long to keep captured text
    # Combine hours and minutes for precise control (e.g., 1h 30m)
    retention_hours = 24
    retention_minutes = 0

    # Inactivity timeout before starting a new segment (in seconds)
    # After this much idle time, new typing creates a new segment
    inactivity_timeout_seconds = 20

    # Whether to persist captured text to disk
    # When enabled, text is encrypted and saved to ~/.local/share/keytee/
    # When disabled, text is lost when KeyTee quits
    persistence_enabled = false

    # Whether to launch KeyTee automatically at login
    launch_at_login = true
    """

    private init() {
        // Use ~/.config/keytee/ for config file
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        configDirectory = homeDir.appendingPathComponent(".config/keytee")
        configFilePath = configDirectory.appendingPathComponent("config.toml")
    }

    // MARK: - Public Methods

    /// Load configuration from disk, or return defaults if file doesn't exist.
    func load() -> Config {
        // Ensure config directory exists
        ensureConfigDirectoryExists()

        // Check if config file exists
        guard FileManager.default.fileExists(atPath: configFilePath.path) else {
            // Create default config file
            createDefaultConfig()
            return Config()
        }

        // Read and parse the file
        do {
            let tomlString = try String(contentsOf: configFilePath, encoding: .utf8)
            let config = try TOMLDecoder().decode(Config.self, from: tomlString)
            return config
        } catch {
            print("KeyTee: Failed to load config: \(error). Using defaults.")
            return Config()
        }
    }

    /// Save configuration to disk.
    ///
    /// - Parameter config: The configuration to save
    /// - Returns: True if save was successful
    @discardableResult
    func save(_ config: Config) -> Bool {
        ensureConfigDirectoryExists()

        do {
            // Encode to TOML
            let tomlString = try TOMLEncoder().encode(config)

            // Add header comment
            let fullContent = """
            # KeyTee Configuration
            # https://github.com/amterp/keytee

            \(tomlString)
            """

            // Write to file
            try fullContent.write(to: configFilePath, atomically: true, encoding: .utf8)
            print("KeyTee: Config saved to \(configFilePath.path)")
            return true
        } catch {
            print("KeyTee: Failed to save config: \(error)")
            return false
        }
    }

    /// Reset configuration to defaults.
    func reset() -> Config {
        let defaultConfig = Config()
        save(defaultConfig)
        return defaultConfig
    }

    /// Get the path to the config file (for display in UI).
    var configPath: String {
        configFilePath.path
    }

    // MARK: - Private Methods

    /// Ensure the config directory exists, creating it if necessary.
    private func ensureConfigDirectoryExists() {
        if !FileManager.default.fileExists(atPath: configDirectory.path) {
            do {
                try FileManager.default.createDirectory(
                    at: configDirectory,
                    withIntermediateDirectories: true
                )
                print("KeyTee: Created config directory at \(configDirectory.path)")
            } catch {
                print("KeyTee: Failed to create config directory: \(error)")
            }
        }
    }

    /// Create the default config file with comments.
    private func createDefaultConfig() {
        do {
            try defaultConfigContent.write(to: configFilePath, atomically: true, encoding: .utf8)
            print("KeyTee: Created default config at \(configFilePath.path)")
        } catch {
            print("KeyTee: Failed to create default config: \(error)")
        }
    }
}
