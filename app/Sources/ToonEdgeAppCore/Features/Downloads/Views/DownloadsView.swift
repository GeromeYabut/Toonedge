import SwiftUI

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
}

@MainActor
public final class DownloadsViewModel: ObservableObject {
    @Published public private(set) var summary: DownloadSummary
    @Published public private(set) var entries: [CacheMetadataEntry]
    @Published public private(set) var cacheFeedback: CacheActionFeedback?
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
    }

    public func load() async {
        entries = await cacheMetadataManager.cacheMetadataEntries()
        if let storageMeasurementService {
            summary = storageMeasurementService.summary(for: entries)
        } else {
            summary = await cacheMetadataManager.downloadSummary()
        }
    }

    public func remove(sourceURL: URL) async {
        do {
            let result = try await cacheMetadataManager.removeCacheMetadata(for: sourceURL)
            cacheFeedback = .success(result)
            await load()
        } catch {
            cacheFeedback = .failure("Could not remove cached chapter.")
        }
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
                TEBanner(
                    title: "Local reading cache",
                    message: "Recent and retained chapter metadata stored on this device.",
                    systemImage: "externaldrive"
                )

                TECard {
                    VStack(spacing: ToonEdgeSpacing.small) {
                        TEListRow(
                            title: "\(viewModel.summary.cachedItemCount) cached chapters",
                            subtitle: viewModel.summary.storageDescription,
                            systemImage: "externaldrive"
                        )

                        TEListRow(
                            title: "\(viewModel.summary.retainedItemCount) retained offline",
                            subtitle: "\(viewModel.summary.recentItemCount) recent cache",
                            systemImage: "arrow.down.circle"
                        )
                    }
                }

                if let feedback = viewModel.cacheFeedback {
                    TEBanner(
                        title: feedback.isFailure ? "Cache action failed" : "Cache updated",
                        message: feedback.message,
                        systemImage: feedback.isFailure ? "exclamationmark.triangle" : "checkmark.circle"
                    )
                }

                if !viewModel.entries.isEmpty {
                    LazyVStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                        Text("Cached chapters")
                            .font(ToonEdgeTypography.sectionTitle)

                        ForEach(viewModel.entries) { entry in
                            TECard {
                                HStack(spacing: ToonEdgeSpacing.medium) {
                                    TEListRow(
                                        title: entry.chapterTitle,
                                        subtitle: "\(entry.seriesTitle) • \(entry.retentionState.title)",
                                        systemImage: entry.retentionState == .retained ? "arrow.down.circle.fill" : "clock"
                                    )

                                    Button {
                                        Task {
                                            await viewModel.remove(sourceURL: entry.sourceURL)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(DownloadsContentLayout(entryCount: viewModel.entries.count).removalLabel(
                                        chapterTitle: entry.chapterTitle,
                                        seriesTitle: entry.seriesTitle
                                    ))
                                    .accessibilityHint("Removes local cached data for this chapter")
                                }
                            }
                        }
                    }
                }

                }
                .padding(ToonEdgeSpacing.large)
                .padding(.bottom, ToonEdgeSpacing.xlarge)
            }
            .navigationTitle("Downloads")
            .task {
                await viewModel.load()
            }
            .toonEdgeScreen()
        }
    }
}
