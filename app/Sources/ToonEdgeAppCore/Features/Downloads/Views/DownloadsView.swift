import SwiftUI

public enum DownloadsContentPhase: Equatable, Sendable {
    case loading
    case empty
    case content

    public init(hasLoaded: Bool, entryCount: Int) {
        if !hasLoaded {
            self = .loading
        } else if entryCount == 0 {
            self = .empty
        } else {
            self = .content
        }
    }
}

public struct DownloadsSeriesGroup: Identifiable, Equatable, Sendable {
    public let seriesTitle: String
    public let entries: [CacheMetadataEntry]

    public var id: String { seriesTitle }
    /// A single chapter already has its own remove button.
    public var offersRemoveAll: Bool { entries.count > 1 }

    public init(seriesTitle: String, entries: [CacheMetadataEntry]) {
        self.seriesTitle = seriesTitle
        self.entries = entries
    }

    /// Keeps the incoming order: a series sits where its first chapter appears.
    public static func groups(from entries: [CacheMetadataEntry]) -> [DownloadsSeriesGroup] {
        var titles: [String] = []
        var entriesByTitle: [String: [CacheMetadataEntry]] = [:]
        for entry in entries {
            if entriesByTitle[entry.seriesTitle] == nil {
                titles.append(entry.seriesTitle)
            }
            entriesByTitle[entry.seriesTitle, default: []].append(entry)
        }
        return titles.map { DownloadsSeriesGroup(seriesTitle: $0, entries: entriesByTitle[$0] ?? []) }
    }
}

public struct DownloadsContentLayout: Equatable, Sendable {
    public let entryCount: Int
    public let usesScrollableContent = true
    public let minimumActionSize: CGFloat = 44

    public init(entryCount: Int) {
        self.entryCount = entryCount
    }

    public let emptyTitle = "No offline chapters"
    public let emptyMessage = "Chapters you download, and chapters kept while you read, appear here."

    public func removalLabel(chapterTitle: String, seriesTitle: String) -> String {
        "Remove \(seriesTitle), \(chapterTitle) from this device"
    }

    public func entryDetail(retentionState: CacheRetentionState) -> String {
        switch retentionState {
        case .retained: "Downloaded"
        case .recent: "Kept while reading"
        }
    }

    public func groupDetail(_ group: DownloadsSeriesGroup) -> String {
        Self.chapterCount(group.entries.count)
    }

    public func removeAllLabel(_ group: DownloadsSeriesGroup) -> String {
        "Remove all \(Self.chapterCount(group.entries.count)) of \(group.seriesTitle) from this device"
    }

    public func removeAllConfirmationTitle(_ group: DownloadsSeriesGroup) -> String {
        "Remove \(Self.chapterCount(group.entries.count)) of \(group.seriesTitle) from this device?"
    }

    public func removeAllConfirmationAction(_ group: DownloadsSeriesGroup) -> String {
        "Remove \(group.entries.count) Chapters"
    }

    private static func chapterCount(_ count: Int) -> String {
        count == 1 ? "1 chapter" : "\(count) chapters"
    }

    public func storageTitle(summary: DownloadSummary) -> String {
        let chapterLabel = summary.cachedItemCount == 1 ? "chapter" : "chapters"
        return "\(summary.cachedItemCount) \(chapterLabel) · \(summary.storageDescription)"
    }

    public func storageDetail(summary: DownloadSummary) -> String {
        "\(summary.retainedItemCount) downloaded · \(summary.recentItemCount) kept while reading"
    }
}

@MainActor
public final class DownloadsViewModel: ObservableObject {
    @Published public private(set) var summary: DownloadSummary
    @Published public private(set) var entries: [CacheMetadataEntry]
    @Published public private(set) var cacheFeedback: CacheActionFeedback?
    @Published public private(set) var hasLoaded: Bool
    @Published public private(set) var failedRemovalURLs: [URL]
    @Published public private(set) var removalInProgressURLs: Set<URL>
    private let cacheMetadataManager: any CacheMetadataManaging
    private let storageMeasurementService: (any CacheStorageMeasuring)?
    private let interactionFeedback: (any InteractionFeedbackProviding)?

    public init(
        cacheMetadataManager: any CacheMetadataManaging,
        interactionFeedback: (any InteractionFeedbackProviding)? = nil,
        storageMeasurementService: (any CacheStorageMeasuring)? = nil
    ) {
        self.cacheMetadataManager = cacheMetadataManager
        self.interactionFeedback = interactionFeedback
        self.storageMeasurementService = storageMeasurementService
        self.summary = DownloadSummary(cachedItemCount: 0, storageDescription: "Loading")
        self.entries = []
        self.cacheFeedback = nil
        self.hasLoaded = false
        self.failedRemovalURLs = []
        self.removalInProgressURLs = []
    }

    public var failedRemovalURL: URL? {
        failedRemovalURLs.first
    }

    public var groups: [DownloadsSeriesGroup] {
        DownloadsSeriesGroup.groups(from: entries)
    }

    public var contentPhase: DownloadsContentPhase {
        DownloadsContentPhase(hasLoaded: hasLoaded, entryCount: entries.count)
    }

    public func load() async {
        entries = await cacheMetadataManager.cacheMetadataEntries()
        if let storageMeasurementService {
            summary = storageMeasurementService.summary(for: entries)
        } else {
            summary = await cacheMetadataManager.downloadSummary()
        }
        hasLoaded = true
    }

    public func remove(sourceURL: URL) async {
        guard removalInProgressURLs.insert(sourceURL).inserted else {
            return
        }

        defer {
            removalInProgressURLs.remove(sourceURL)
        }

        do {
            let result = try await cacheMetadataManager.removeCacheMetadata(for: sourceURL)
            cacheFeedback = .success(result)
            if let event = InteractionFeedbackOutcomePolicy.cacheEvent(for: result) {
                interactionFeedback?.emit(event)
            }
            failedRemovalURLs.removeAll { $0 == sourceURL }
            await load()
        } catch {
            cacheFeedback = .failure("Couldn’t remove this offline copy. Try again.")
            failedRemovalURLs = [sourceURL]
        }
    }

    public func removeAll(sourceURLs: [URL]) async {
        let targets = sourceURLs.filter { removalInProgressURLs.insert($0).inserted }
        guard !targets.isEmpty else {
            return
        }

        defer {
            removalInProgressURLs.subtract(targets)
        }

        var failed: [URL] = []
        for target in targets {
            do {
                _ = try await cacheMetadataManager.removeCacheMetadata(for: target)
            } catch {
                failed.append(target)
            }
        }

        failedRemovalURLs = failed
        if failed.isEmpty {
            cacheFeedback = CacheActionFeedback(
                result: .removed,
                message: "\(targets.count) offline copies removed.",
                isFailure: false
            )
            if let event = InteractionFeedbackOutcomePolicy.cacheEvent(for: .removed) {
                interactionFeedback?.emit(event)
            }
        } else {
            cacheFeedback = .failure("Couldn’t remove \(failed.count) of \(targets.count) offline copies. Try again.")
        }
        await load()
    }

    public func retryFailedRemoval() async {
        if failedRemovalURLs.count > 1 {
            await removeAll(sourceURLs: failedRemovalURLs)
        } else if let failedRemovalURL {
            await remove(sourceURL: failedRemovalURL)
        }
    }
}

public struct DownloadsView: View {
    @StateObject private var viewModel: DownloadsViewModel
    @State private var pendingRemoveAll: DownloadsSeriesGroup?

    public init(dependencies: AppDependencies) {
        self._viewModel = StateObject(
            wrappedValue: DownloadsViewModel(
                cacheMetadataManager: dependencies.cacheMetadataService,
                interactionFeedback: dependencies.interactionFeedback,
                storageMeasurementService: dependencies.cacheStorageMeasurementService
            )
        )
    }

    public var body: some View {
        List {
            if viewModel.hasLoaded {
                storageHeader
                    .modifier(DownloadsPlainListRow())
            }

            if viewModel.cacheFeedback != nil {
                feedback
                    .modifier(DownloadsPlainListRow())
            }

            switch viewModel.contentPhase {
            case .loading:
                loadingState
                    .modifier(DownloadsPlainListRow())
            case .empty:
                emptyState
                    .modifier(DownloadsPlainListRow())
            case .content:
                ForEach(viewModel.groups) { group in
                    seriesSection(group)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("downloads.root")
        .navigationTitle("Downloads")
        .task {
            await viewModel.load()
        }
        .confirmationDialog(
            pendingRemoveAll.map(layout.removeAllConfirmationTitle) ?? "",
            isPresented: Binding(
                get: { pendingRemoveAll != nil },
                set: { if !$0 { pendingRemoveAll = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingRemoveAll
        ) { group in
            Button(layout.removeAllConfirmationAction(group), role: .destructive) {
                Task {
                    await viewModel.removeAll(sourceURLs: group.entries.map(\.sourceURL))
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("You’ll need a connection to read them again.")
        }
        .toonEdgeScreen()
    }

    private var layout: DownloadsContentLayout {
        DownloadsContentLayout(entryCount: viewModel.entries.count)
    }

    private var storageHeader: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
            Text(layout.storageTitle(summary: viewModel.summary))
                .font(ToonEdgeTypography.title)
                .foregroundStyle(ToonEdgeColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(layout.storageDetail(summary: viewModel.summary))
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("downloads.storageHeader")
    }

    @ViewBuilder
    private var feedback: some View {
        if let feedback = viewModel.cacheFeedback {
            if feedback.isFailure {
                HStack(alignment: .center, spacing: ToonEdgeSpacing.medium) {
                    Label(feedback.message, systemImage: "exclamationmark.triangle")
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("downloads.feedback.failure")

                    Spacer(minLength: ToonEdgeSpacing.small)

                    if viewModel.failedRemovalURL != nil {
                        Button("Retry") {
                            Task {
                                await viewModel.retryFailedRemoval()
                            }
                        }
                        .buttonStyle(TEActionStyle(surface: .elevated))
                        .disabled(viewModel.failedRemovalURL.map(viewModel.removalInProgressURLs.contains) == true)
                        .accessibilityIdentifier("downloads.removal.retry")
                    }
                }
            } else {
                Label(feedback.message, systemImage: "checkmark.circle")
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .accessibilityIdentifier("downloads.feedback.success")
            }
        }
    }

    private var loadingState: some View {
        ProgressView("Loading downloads")
            .font(ToonEdgeTypography.body)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            .accessibilityIdentifier("downloads.loading")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
            Text(layout.emptyTitle)
                .font(ToonEdgeTypography.sectionTitle)
            Text(layout.emptyMessage)
                .font(ToonEdgeTypography.body)
                .foregroundStyle(ToonEdgeColor.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("downloads.empty")
    }

    private func seriesSection(_ group: DownloadsSeriesGroup) -> some View {
        Section {
            ForEach(group.entries) { entry in
                downloadRow(entry)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .swipeActions(edge: .trailing) {
                        Button("Remove", role: .destructive) {
                            Task {
                                await viewModel.remove(sourceURL: entry.sourceURL)
                            }
                        }
                        .tint(ToonEdgeColor.failure)
                    }
            }
        } header: {
            seriesHeader(group)
        }
    }

    private func seriesHeader(_ group: DownloadsSeriesGroup) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: ToonEdgeSpacing.medium) {
                seriesTitle(group)
                Spacer(minLength: ToonEdgeSpacing.small)
                removeAllButton(group)
            }
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                seriesTitle(group)
                removeAllButton(group)
            }
        }
        .textCase(nil)
        .padding(.vertical, ToonEdgeSpacing.xsmall)
    }

    private func seriesTitle(_ group: DownloadsSeriesGroup) -> some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
            Text(group.seriesTitle)
                .font(ToonEdgeTypography.sectionTitle)
                .foregroundStyle(ToonEdgeColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(layout.groupDetail(group))
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func removeAllButton(_ group: DownloadsSeriesGroup) -> some View {
        if group.offersRemoveAll {
            Button("Remove All") {
                pendingRemoveAll = group
            }
            .font(ToonEdgeTypography.caption.weight(.semibold))
            .foregroundStyle(ToonEdgeColor.accent)
            .buttonStyle(.plain)
            .frame(minHeight: layout.minimumActionSize)
            .contentShape(Rectangle())
            .fixedSize()
            .accessibilityLabel(layout.removeAllLabel(group))
            .accessibilityIdentifier("downloads.removeAll.\(group.seriesTitle)")
        }
    }

    private func downloadRow(_ entry: CacheMetadataEntry) -> some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            Image(systemName: entry.retentionState == .retained ? "arrow.down.circle.fill" : "clock")
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text(entry.chapterTitle)
                    .font(ToonEdgeTypography.body.weight(.semibold))
                    .foregroundStyle(ToonEdgeColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(layout.entryDetail(retentionState: entry.retentionState))
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: ToonEdgeSpacing.small)

            Button {
                Task {
                    await viewModel.remove(sourceURL: entry.sourceURL)
                }
            } label: {
                Image(systemName: "trash")
                    .frame(width: layout.minimumActionSize, height: layout.minimumActionSize)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.removalInProgressURLs.contains(entry.sourceURL))
            .accessibilityLabel(layout.removalLabel(
                chapterTitle: entry.chapterTitle,
                seriesTitle: entry.seriesTitle
            ))
            .accessibilityHint("Removes this chapter's offline copy")
        }
        .modifier(TEEditorialRowStyle())
        .accessibilityIdentifier("downloads.entry.\(entry.id.uuidString)")
    }
}

private struct DownloadsPlainListRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
