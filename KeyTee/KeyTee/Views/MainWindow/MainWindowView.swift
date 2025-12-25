//
//  MainWindowView.swift
//  KeyTee
//
//  The main window displaying captured keystroke history.
//

import SwiftUI

/// Main window view with a sidebar for navigation and a detail area for content.
///
/// SwiftUI's `NavigationSplitView` (macOS 13+) creates a sidebar-detail layout
/// similar to Finder or Mail. The sidebar lists buckets (app/window contexts),
/// and the detail area shows the captured text for the selected bucket.
struct MainWindowView: View {
    // App state containing captured text and services
    @Bindable var appState: AppState

    // Track which item is selected in the sidebar
    @State private var selectedItem: SidebarItem? = .all

    // Sort order for bucket list
    @State private var sortByActivity: Bool = true

    var body: some View {
        NavigationSplitView {
            // Sidebar with "All" and bucket list
            SidebarView(
                appState: appState,
                selection: $selectedItem,
                sortByActivity: $sortByActivity
            )
        } detail: {
            // Detail area showing captured text
            DetailView(selectedItem: selectedItem, appState: appState)
        }
        .frame(minWidth: 700, minHeight: 450)
        .onAppear {
            // Check if we need onboarding when window appears
            if !appState.accessibilityChecker.isAccessibilityEnabled {
                appState.showOnboarding = true
            }
        }
    }
}

/// Represents items that can be selected in the sidebar.
enum SidebarItem: Hashable {
    case all
    case bucket(id: UUID)
}

/// Sidebar showing "All" view and list of buckets.
struct SidebarView: View {
    @Bindable var appState: AppState
    @Binding var selection: SidebarItem?
    @Binding var sortByActivity: Bool

    // Track section expansion state to prevent layout shift
    @State private var isContextsExpanded: Bool = true

    private var sortedBuckets: [Bucket] {
        sortByActivity ? appState.captureStore.bucketsByActivity : appState.captureStore.bucketsByName
    }

    var body: some View {
        List(selection: $selection) {
            // "All" shows all text chronologically
            // Using NavigationLink-style row for better click handling
            HStack {
                Label("All", systemImage: "tray.full")
                Spacer()
                Text("\(appState.captureStore.totalCharacterCount)")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            .tag(SidebarItem.all)
            .contentShape(Rectangle())  // Make entire row clickable

            // Use DisclosureGroup for stable expand/collapse behavior
            Section {
                DisclosureGroup(isExpanded: $isContextsExpanded) {
                    if sortedBuckets.isEmpty {
                        Text("No captures yet")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(sortedBuckets) { bucket in
                            BucketRow(bucket: bucket)
                                .tag(SidebarItem.bucket(id: bucket.id))
                                .contentShape(Rectangle())
                                .contextMenu {
                                    Button("Clear This Context", role: .destructive) {
                                        appState.captureStore.clearBucket(bucket)
                                        if case .bucket(let id) = selection, id == bucket.id {
                                            selection = .all
                                        }
                                    }
                                }
                        }
                    }
                } label: {
                    HStack {
                        Text("Contexts")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)  // Space between chevron and text

                        Spacer()

                        // Sort toggle button
                        Button {
                            sortByActivity.toggle()
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: sortByActivity ? "arrow.up.arrow.down" : "textformat.abc")
                                    .font(.caption)
                                Text(sortByActivity ? "Recent" : "A-Z")
                                    .font(.caption2)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help(sortByActivity ? "Sorted by most recent activity" : "Sorted alphabetically")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("KeyTee")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.captureStore.clearAll()
                    selection = .all
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
                .disabled(appState.captureStore.isEmpty)
            }
        }
    }
}

/// A row in the bucket list showing context info.
struct BucketRow: View {
    let bucket: Bucket

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(bucket.context.appName)
                    .font(.headline)
                    .lineLimit(1)

                if !bucket.context.windowTitle.isEmpty {
                    Text(bucket.context.windowTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(bucket.totalCharacterCount)")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
    }
}

/// Detail view showing content for the selected sidebar item.
struct DetailView: View {
    let selectedItem: SidebarItem?
    @Bindable var appState: AppState

    var body: some View {
        switch selectedItem {
        case .all:
            AllTextView(appState: appState)
        case .bucket(let id):
            if let bucket = appState.captureStore.bucket(withId: id) {
                BucketDetailView(bucket: bucket, appState: appState)
            } else {
                ContentUnavailableView(
                    "Bucket Not Found",
                    systemImage: "questionmark.folder",
                    description: Text("This context may have been cleared")
                )
            }
        case nil:
            ContentUnavailableView(
                "Select a Context",
                systemImage: "sidebar.left",
                description: Text("Choose \"All\" or a specific app context from the sidebar")
            )
        }
    }
}

/// Shows all captured text in chronological order across all contexts.
struct AllTextView: View {
    @Bindable var appState: AppState

    var body: some View {
        Group {
            if appState.captureStore.isEmpty {
                ContentUnavailableView(
                    "No Text Captured",
                    systemImage: "keyboard",
                    description: Text(appState.accessibilityChecker.isAccessibilityEnabled
                        ? "Start typing in any app to see captured text here"
                        : "Grant Accessibility permission to start capturing")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(appState.captureStore.allSegmentsChronological, id: \.segment.id) { item in
                            SegmentCard(
                                segment: item.segment,
                                contextName: item.bucket.context.displayName,
                                lastActivityAt: item.bucket.lastActivityAt,
                                inactivityTimeout: appState.captureStore.inactivityTimeout
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Status indicator
                StatusIndicator(appState: appState)

                CopyButton(text: copyAllText(), disabled: appState.captureStore.isEmpty)
            }
        }
        .navigationTitle("All Captured Text")
    }

    private func copyAllText() -> String {
        appState.captureStore.allSegmentsChronological
            .map { "[\($0.bucket.context.displayName)]\n\($0.segment.text)" }
            .joined(separator: "\n\n---\n\n")
    }
}

/// Shows segments for a specific bucket/context.
struct BucketDetailView: View {
    let bucket: Bucket
    @Bindable var appState: AppState

    var body: some View {
        Group {
            if bucket.segments.isEmpty {
                ContentUnavailableView(
                    "No Text in This Context",
                    systemImage: "text.cursor",
                    description: Text("Text captured in \(bucket.context.displayName) will appear here")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(bucket.segments.reversed()) { segment in
                            SegmentCard(
                                segment: segment,
                                contextName: nil,
                                lastActivityAt: bucket.lastActivityAt,
                                inactivityTimeout: appState.captureStore.inactivityTimeout
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                StatusIndicator(appState: appState)

                CopyButton(text: bucket.allText, disabled: bucket.segments.isEmpty)
            }
        }
        .navigationTitle(bucket.context.displayName)
    }
}

/// A card displaying a single segment of captured text.
struct SegmentCard: View {
    let segment: Segment
    let contextName: String?  // Shown in "All" view, nil in bucket detail
    let lastActivityAt: Date  // When the bucket last had activity
    let inactivityTimeout: TimeInterval  // Seconds until segment ends

    // Timer to update countdown
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Whether this segment is still actively counting down
    /// (segment.isActive means endedAt is nil, but we also check if timeout hasn't expired)
    private var isCountingDown: Bool {
        guard segment.isActive else { return false }
        let elapsed = now.timeIntervalSince(lastActivityAt)
        return elapsed < inactivityTimeout
    }

    /// Whether the segment has effectively ended (timeout expired, even if endedAt not set yet)
    private var hasEffectivelyEnded: Bool {
        if segment.endedAt != nil { return true }
        let elapsed = now.timeIntervalSince(lastActivityAt)
        return elapsed >= inactivityTimeout
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with timestamp and optional context
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    // Time range display
                    Text(timeRangeString)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    // Context name (in All view)
                    if let contextName = contextName {
                        Text(contextName)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                Spacer()

                // Active indicator with countdown (only shown while counting down)
                if isCountingDown {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text(countdownString)
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.green)
                    }
                }
            }

            // Text content
            Text(segment.text.isEmpty ? "(empty)" : segment.text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(segment.text.isEmpty ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Footer with character count and copy button
            HStack {
                Text("\(segment.characterCount) characters")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                CopyButton(text: segment.text, disabled: segment.text.isEmpty, compact: true)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
        .onReceive(timer) { _ in
            // Only update if we're still counting down
            if segment.isActive {
                now = Date()
            }
        }
    }

    /// Format the time range as "yyyy-MM-dd HH:mm:ss – HH:mm:ss"
    /// Shows end time once segment has effectively ended (timeout expired)
    private var timeRangeString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        let startStr = dateFormatter.string(from: segment.startedAt)

        // Determine the effective end time
        let effectiveEndTime: Date?
        if let endedAt = segment.endedAt {
            effectiveEndTime = endedAt
        } else if hasEffectivelyEnded {
            // Timeout expired - use lastActivityAt as the effective end time
            effectiveEndTime = lastActivityAt
        } else {
            effectiveEndTime = nil
        }

        if let endTime = effectiveEndTime {
            // Show time range
            let startDay = Calendar.current.startOfDay(for: segment.startedAt)
            let endDay = Calendar.current.startOfDay(for: endTime)

            if startDay == endDay {
                // Same day: show full start, time-only end
                let endStr = timeFormatter.string(from: endTime)
                return "\(startStr) – \(endStr)"
            } else {
                // Different days: show full dates for both
                let endStr = dateFormatter.string(from: endTime)
                return "\(startStr) – \(endStr)"
            }
        } else {
            // Still actively counting down: just show start time
            return startStr
        }
    }

    /// Countdown string showing time until segment ends
    private var countdownString: String {
        let elapsed = now.timeIntervalSince(lastActivityAt)
        let remaining = max(0, inactivityTimeout - elapsed)

        let seconds = Int(remaining) % 60
        let minutes = Int(remaining) / 60

        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return "\(seconds)s"
        }
    }
}

/// Copy button with visual feedback.
struct CopyButton: View {
    let text: String
    let disabled: Bool
    var compact: Bool = false

    @State private var showCopied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)

            // Show feedback
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopied = true
            }

            // Reset after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCopied = false
                }
            }
        } label: {
            if compact {
                // Compact version for segment cards
                Label(showCopied ? "Copied!" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(showCopied ? .green : .secondary)
            } else {
                // Full version for toolbar
                Label(showCopied ? "Copied!" : "Copy All", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(showCopied ? .green : .primary)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .animation(.easeInOut(duration: 0.2), value: showCopied)
    }
}

/// Status indicator showing capture state.
struct StatusIndicator: View {
    @Bindable var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        if !appState.accessibilityChecker.isAccessibilityEnabled {
            return .orange
        } else if appState.isPaused {
            return .yellow
        } else {
            return .green
        }
    }

    private var statusText: String {
        if !appState.accessibilityChecker.isAccessibilityEnabled {
            return "No Permission"
        } else if appState.isPaused {
            return "Paused"
        } else {
            return "Capturing"
        }
    }
}

#Preview {
    MainWindowView(appState: AppState())
}
