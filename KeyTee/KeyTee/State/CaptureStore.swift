//
//  CaptureStore.swift
//  KeyTee
//
//  Central state container for captured text, organized by buckets.
//

import Foundation

/// Central state container for all captured text.
///
/// CaptureStore is the single source of truth for captured keystrokes.
/// It organizes text into buckets (by app/window context) and segments
/// (by typing sessions separated by inactivity).
///
/// Key responsibilities:
/// - Route captured text to the correct bucket based on current context
/// - Create new buckets and segments as needed
/// - Apply inactivity timeout for segmentation
/// - Provide data for UI views (all segments, bucket list, etc.)
/// - Handle retention cleanup (removing old data)
@Observable
class CaptureStore {

    // MARK: - Properties

    /// All buckets, keyed by context for fast lookup
    var buckets: [Bucket] = []

    /// Inactivity timeout in seconds (default: 20 seconds for testing, will be configurable)
    /// After this much inactivity, a new segment is created
    var inactivityTimeout: TimeInterval = 20

    /// Retention period in seconds (default: 24 hours)
    /// Segments older than this are automatically removed
    var retentionPeriod: TimeInterval = 24 * 60 * 60

    // MARK: - Computed Properties

    /// All segments across all buckets, sorted chronologically (newest first)
    var allSegmentsChronological: [(bucket: Bucket, segment: Segment)] {
        buckets
            .flatMap { bucket in
                bucket.segments.map { (bucket: bucket, segment: $0) }
            }
            .sorted { $0.segment.startedAt > $1.segment.startedAt }
    }

    /// Buckets sorted by most recent activity (for sidebar)
    var bucketsByActivity: [Bucket] {
        buckets.sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    /// Buckets sorted alphabetically by display name
    var bucketsByName: [Bucket] {
        buckets.sorted { $0.context.displayName.localizedCaseInsensitiveCompare($1.context.displayName) == .orderedAscending }
    }

    /// Total character count across all buckets
    var totalCharacterCount: Int {
        buckets.reduce(0) { $0 + $1.totalCharacterCount }
    }

    /// Whether there's any captured text
    var isEmpty: Bool {
        buckets.isEmpty || buckets.allSatisfy { $0.segments.isEmpty }
    }

    // MARK: - Text Capture

    /// Append text to the appropriate bucket based on the given context.
    ///
    /// - Parameters:
    ///   - text: The text to append
    ///   - context: The app/window context where the text was typed
    func appendText(_ text: String, to context: WindowContext) {
        let bucket = findOrCreateBucket(for: context)
        bucket.appendText(text, inactivityTimeout: inactivityTimeout)
    }

    /// Handle a backspace in the given context.
    ///
    /// - Parameter context: The app/window context where backspace was pressed
    func handleBackspace(in context: WindowContext) {
        guard let bucket = findBucket(for: context) else { return }
        bucket.handleBackspace()
    }

    /// Handle a newline in the given context.
    ///
    /// - Parameter context: The app/window context where enter was pressed
    func handleNewline(in context: WindowContext) {
        appendText("\n", to: context)
    }

    /// Handle pasted text in the given context.
    ///
    /// - Parameters:
    ///   - text: The pasted text
    ///   - context: The app/window context where the paste occurred
    func handlePaste(_ text: String, in context: WindowContext) {
        appendText(text, to: context)
    }

    // MARK: - Bucket Management

    /// Find an existing bucket for the given context, or create a new one.
    private func findOrCreateBucket(for context: WindowContext) -> Bucket {
        if let existing = findBucket(for: context) {
            return existing
        }

        // Create new bucket
        let bucket = Bucket(context: context)
        buckets.append(bucket)
        return bucket
    }

    /// Find an existing bucket matching the given context.
    private func findBucket(for context: WindowContext) -> Bucket? {
        buckets.first { $0.context.matches(appBundleId: context.appBundleId, windowTitle: context.windowTitle) }
    }

    /// Get a bucket by its ID.
    func bucket(withId id: UUID) -> Bucket? {
        buckets.first { $0.id == id }
    }

    // MARK: - Clearing

    /// Clear a specific bucket (remove all its segments).
    func clearBucket(_ bucket: Bucket) {
        if let index = buckets.firstIndex(where: { $0.id == bucket.id }) {
            buckets.remove(at: index)
        }
    }

    /// Clear all captured text (remove all buckets).
    func clearAll() {
        buckets.removeAll()
    }

    // MARK: - Retention

    /// Remove segments older than the retention period.
    /// Called periodically by the retention manager.
    func pruneOldSegments() {
        for bucket in buckets {
            bucket.pruneOldSegments(retentionPeriod: retentionPeriod)
        }

        // Remove empty buckets
        buckets.removeAll { $0.segments.isEmpty }
    }

    // MARK: - Serialization (for persistence)

    /// Encode to JSON for disk persistence.
    func encodeToJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(buckets)
    }

    /// Decode from JSON when loading from disk.
    func decodeFromJSON(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        buckets = try decoder.decode([Bucket].self, from: data)
    }
}
