//
//  WindowContext.swift
//  KeyTee
//
//  Represents the context (app + window) where text was captured.
//

import Foundation

/// Identifies a specific app and window combination.
///
/// Text is grouped into buckets by WindowContext. For example:
/// - "Safari — Claude.ai" and "Safari — Gmail" are different contexts
/// - "VS Code — main.swift" and "VS Code — utils.swift" are different contexts
///
/// This allows users to find text they typed in a specific context,
/// rather than searching through a single chronological stream.
struct WindowContext: Identifiable, Hashable, Codable {
    /// Unique identifier for this context
    let id: UUID

    /// The app's bundle identifier (e.g., "com.apple.Safari")
    /// Used to identify the app reliably across sessions
    let appBundleId: String

    /// Human-readable app name (e.g., "Safari")
    let appName: String

    /// Window title at the time of capture (e.g., "Claude.ai")
    /// May be empty if window title couldn't be retrieved
    let windowTitle: String

    /// When this context was first seen
    let createdAt: Date

    /// Display name for the UI, combining app and window
    var displayName: String {
        if windowTitle.isEmpty {
            return appName
        }
        return "\(appName) — \(windowTitle)"
    }

    /// Short display name (just the app)
    var shortName: String {
        appName
    }

    init(
        id: UUID = UUID(),
        appBundleId: String,
        appName: String,
        windowTitle: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.appBundleId = appBundleId
        self.appName = appName
        self.windowTitle = windowTitle
        self.createdAt = createdAt
    }

    /// Check if two contexts represent the same app+window combination.
    /// Used to find existing buckets when text is captured.
    func matches(appBundleId: String, windowTitle: String) -> Bool {
        return self.appBundleId == appBundleId && self.windowTitle == windowTitle
    }
}

// MARK: - Hashable conformance for use in dictionaries/sets

extension WindowContext {
    func hash(into hasher: inout Hasher) {
        // Hash by app+window, not by id, so we can find matching contexts
        hasher.combine(appBundleId)
        hasher.combine(windowTitle)
    }

    static func == (lhs: WindowContext, rhs: WindowContext) -> Bool {
        // Two contexts are equal if they represent the same app+window
        lhs.appBundleId == rhs.appBundleId && lhs.windowTitle == rhs.windowTitle
    }
}
