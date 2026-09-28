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

public struct DownloadsContentLayout: Equatable, Sendable {
    public let entryCount: Int
    public let usesScrollableContent = true
    public let minimumActionSize: CGFloat = 44

    public init(entryCount: Int) {
        self.entryCount = entryCount
    }

    public func removalLabel(chapterTitle: String, seriesTitle: String) -> String {
        "Remove \(seriesTitle), \(chapterTitle) from cache"
    }

    public func storageTitle(summary: DownloadSummary) -> String {
        let chapterLabel = summary.cachedItemCount == 1 ? "chapter" : "chapters"
        return "\(summary.cachedItemCount) \(chapterLabel) · \(summary.storageDescription)"
    }

    public func storageDetail(summary: DownloadSummary) -> String {
        "\(summary.retainedItemCount) retained references · \(summary.recentItemCount) recent references"
    }
}

@MainActor
public final class DownloadsViewModel: ObservableObject {
    @Published public private(set) var summary: DownloadSummary
    @Published public private(set) var entries: [CacheMetadataEntry]
    @Published public private(set) var cacheFeedback: CacheActionFeedback?
    @Published public private(set) var hasLoaded: Bool
    @Published public private(set) var failedRemovalURL: URL?
    @Published public private(set) var removalInProgressURLs: Set<URL>
    private let cacheMetadataManager: any CacheMetadataManaging
    private let storageMeasurementService: (any CacheStorageMeasuring)?

    public init(
        cacheMetadataManager: any CacheMetadataManaging,
        storageMeasurementService: (any CacheStorageMeasuring)? = nil
    ) {
        self.cacheMetadataManager = cacheMetadataManager
        self.storageMeasurementService = storageMeasurementService
        self.summary = DownloadSummary(cachedItemCount: 0, storageDescription: "Loading")
        self.entries = []
        self.cacheFeedback = nil
        self.hasLoaded = false
        self.failedRemovalURL = nil
        self.removalInProgressURLs = []
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
            if failedRemovalURL == sourceURL {
                failedRemovalURL = nil
            }
            await load()
        } catch {
            cacheFeedback = .failure("Could not remove cached chapter.")
            failedRemovalURL = sourceURL
        }
    }

    public func retryFailedRemoval() async {
        guard let failedRemovalURL else {
            return
        }
        await remove(sourceURL: failedRemovalURL)
    }
}

public struct DownloadsView: View {
    @StateObject private var viewModel: DownloadsViewModel

    public init(dependencies: AppDependencies) {
        self._viewModel = StateObject(
            wrappedValue: DownloadsViewModel(
                cacheMetadataManager: dependencies.cacheMetadataService,
                storageMeasurementService: dependencies.cacheStorageMeasurementService
            )
        )
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
                    if viewModel.hasLoaded {
                        storageHeader
                    }

                    feedback

                    switch viewModel.contentPhase {
                    case .loading:
                        loadingState
                    case .empty:
                        emptyState
                    case .content:
                        contentRows
                    }
                }
                .padding(ToonEdgeSpacing.large)
                .padding(.bottom, ToonEdgeSpacing.xlarge)
            }
            .accessibilityIdentifier("downloads.root")
            .navigationTitle("Downloads")
            .task {
                await viewModel.load()
            }
            .toonEdgeScreen()
        }
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
            Text("No cached chapters")
                .font(ToonEdgeTypography.sectionTitle)
            Text("Chapters cached while reading will appear here.")
                .font(ToonEdgeTypography.body)
                .foregroundStyle(ToonEdgeColor.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("downloads.empty")
    }

    private var contentRows: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
            Text("Cached chapters")
                .font(ToonEdgeTypography.sectionTitle)

            TEEditorialGroup(
                viewModel.entries,
                spacing: 0,
                separatorInset: 44 + ToonEdgeSpacing.medium
            ) { entry in
                downloadRow(entry)
            }
            .accessibilityIdentifier("downloads.entries")
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
                Text("\(entry.seriesTitle) · \(entry.retentionState.title) reference")
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
            .accessibilityHint("Removes local cached data for this chapter")
        }
        .modifier(TEEditorialRowStyle())
        .accessibilityIdentifier("downloads.entry.\(entry.id.uuidString)")
    }
}
