//
//  Bucket.swift
//  KeyTee
//
//  A bucket groups captured text segments by app/window context.
//

import Foundation

/// A bucket groups captured text segments by app/window context.
///
/// Each unique app+window combination gets its own bucket. For example:
/// - "Safari — Claude.ai" has one bucket
/// - "Safari — Gmail" has another bucket
/// - "VS Code — main.swift" has its own bucket
///
/// Within each bucket, text is further divided into segments based on
/// inactivity periods (default 5 minutes). This keeps related typing
/// together while separating unrelated sessions.
@Observable
class Bucket: Identifiable, Codable {
    /// Unique identifier
    let id: UUID

    /// The app/window context this bucket captures from
    let context: WindowContext

    /// Segments of captured text, ordered by start time
    var segments: [Segment]

    /// When text was last captured in this bucket
    var lastActivityAt: Date

    /// Total character count across all segments
    var totalCharacterCount: Int {
        segments.reduce(0) { $0 + $1.characterCount }
    }

    /// The currently active segment (if any)
    var activeSegment: Segment? {
        segments.last { $0.isActive }
    }

    /// All text concatenated (for copy functionality)
    var allText: String {
        segments.map { $0.text }.joined(separator: "\n\n")
    }

    init(
        id: UUID = UUID(),
        context: WindowContext,
        segments: [Segment] = [],
        lastActivityAt: Date = Date()
    ) {
        self.id = id
        self.context = context
        self.segments = segments
        self.lastActivityAt = lastActivityAt
    }

    // MARK: - Text Manipulation

    /// Append text to the current segment, or create a new segment if needed.
    ///
    /// - Parameters:
    ///   - text: The text to append
    ///   - inactivityTimeout: Seconds of inactivity that triggers a new segment
    func appendText(_ text: String, inactivityTimeout: TimeInterval) {
        let now = Date()

        // Check if we need a new segment due to inactivity
        if shouldStartNewSegment(at: now, timeout: inactivityTimeout) {
            // Close the previous segment
            if let lastSegment = segments.last, lastSegment.isActive {
                lastSegment.endedAt = lastActivityAt
            }
            // Create a new segment
            let newSegment = Segment(startedAt: now, text: text)
            segments.append(newSegment)
        } else if let activeSegment = segments.last {
            // Append to existing segment
            activeSegment.text += text
        } else {
            // First segment in this bucket
            let newSegment = Segment(startedAt: now, text: text)
            segments.append(newSegment)
        }

        lastActivityAt = now
    }

    /// Handle a backspace by removing the last character from the active segment.
    func handleBackspace() {
        guard let activeSegment = segments.last, !activeSegment.text.isEmpty else {
            return
        }
        activeSegment.text.removeLast()
        lastActivityAt = Date()
    }

    /// Check if we should start a new segment based on inactivity.
    private func shouldStartNewSegment(at date: Date, timeout: TimeInterval) -> Bool {
        // Always need a segment if we have none
        guard !segments.isEmpty else { return true }

        // Check if enough time has passed since last activity
        let timeSinceLastActivity = date.timeIntervalSince(lastActivityAt)
        return timeSinceLastActivity > timeout
    }

    /// Remove segments older than the retention period.
    ///
    /// - Parameter retentionPeriod: How long to keep segments (in seconds)
    /// - Returns: Number of segments removed
    @discardableResult
    func pruneOldSegments(retentionPeriod: TimeInterval) -> Int {
        let cutoff = Date().addingTimeInterval(-retentionPeriod)
        let originalCount = segments.count
        segments.removeAll { segment in
            // Remove if the segment ended before the cutoff
            // Active segments (endedAt == nil) are never pruned
            if let endedAt = segment.endedAt {
                return endedAt < cutoff
            }
            // For active segments, check startedAt
            return segment.startedAt < cutoff && segment.text.isEmpty
        }
        return originalCount - segments.count
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, context, segments, lastActivityAt
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        context = try container.decode(WindowContext.self, forKey: .context)
        segments = try container.decode([Segment].self, forKey: .segments)
        lastActivityAt = try container.decode(Date.self, forKey: .lastActivityAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(context, forKey: .context)
        try container.encode(segments, forKey: .segments)
        try container.encode(lastActivityAt, forKey: .lastActivityAt)
    }
}
