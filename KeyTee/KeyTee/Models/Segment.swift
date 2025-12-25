//
//  Segment.swift
//  KeyTee
//
//  A segment of captured text within a bucket.
//

import Foundation

/// A segment of captured text within a bucket.
///
/// Segments represent continuous typing sessions. A new segment is created when:
/// - The user starts typing in a context for the first time
/// - The user returns to a context after an inactivity period (default 5 minutes)
///
/// This prevents unrelated typing sessions (e.g., morning vs. evening)
/// from being concatenated into one long blob of text.
///
/// Using @Observable for automatic UI updates when text changes.
@Observable
class Segment: Identifiable, Codable {
    /// Unique identifier
    let id: UUID

    /// When this segment started (first keystroke)
    let startedAt: Date

    /// The captured text content
    var text: String

    /// When this segment ended (last keystroke before inactivity timeout)
    /// Nil if this is the currently active segment
    var endedAt: Date?

    /// Whether this segment is still receiving keystrokes
    var isActive: Bool {
        endedAt == nil
    }

    /// Character count for display
    var characterCount: Int {
        text.count
    }

    /// Preview of the text for list views (first line, truncated)
    var preview: String {
        let firstLine = text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? text
        if firstLine.count > 100 {
            return String(firstLine.prefix(100)) + "..."
        }
        return firstLine
    }

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        text: String = "",
        endedAt: Date? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.text = text
        self.endedAt = endedAt
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, startedAt, text, endedAt
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        text = try container.decode(String.self, forKey: .text)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
    }
}
