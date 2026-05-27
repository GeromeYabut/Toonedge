import SwiftUI

public struct HomeView: View {
    private let dependencies: AppDependencies
    @Binding private var router: AppRouter
    @State private var snapshot = HomeSnapshot(continueReading: [], recentlyUpdated: [], library: [])
    @State private var hasLoadedSnapshot = false
    @State private var isRefreshingUpdates = false
    @State private var refreshMessage: String?

    public init(dependencies: AppDependencies, router: Binding<AppRouter>) {
        self.dependencies = dependencies
        self._router = router
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ToonEdgeSpacing.xlarge) {
                    topBar
                    refreshStatus

                    if hasLoadedSnapshot && snapshot.isEmpty {
                        emptyState
                    } else {
                        continueReadingSection
                        section("Recently Updated", items: snapshot.recentlyUpdated, style: .compact)
                        section("All Library", items: snapshot.library, style: .compact)
                    }
                }
                .padding(ToonEdgeSpacing.large)
            }
            .task {
                await reloadSnapshot()
            }
            .refreshable {
                await refreshUpdates()
            }
            .toonEdgeScreen()
        }
    }

    private var topBar: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            searchEntry
            settingsButton
            refreshButton
        }
    }

    private var searchEntry: some View {
        Button {
            router.presentSearch()
        } label: {
            HStack(spacing: ToonEdgeSpacing.small) {
                Image(systemName: "globe")
                    .font(ToonEdgeTypography.body.weight(.semibold))
                    .foregroundStyle(ToonEdgeColor.textSecondary)

                Text("Search or enter website")
                    .font(ToonEdgeTypography.body)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, ToonEdgeSpacing.large)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(ToonEdgeColor.panel, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(ToonEdgeColor.border)
            )
        }
        .buttonStyle(.plain)
    }

    private var settingsButton: some View {
        Button {
            router.selectedTab = .settings
        } label: {
            Image(systemName: "gearshape")
                .font(ToonEdgeTypography.body.weight(.semibold))
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .frame(width: 44, height: 44)
                .background(ToonEdgeColor.panel, in: Circle())
                .overlay(Circle().stroke(ToonEdgeColor.border))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }

    private var refreshButton: some View {
        Button {
            Task {
                await refreshUpdates()
            }
        } label: {
            Image(systemName: isRefreshingUpdates ? "hourglass" : "arrow.clockwise")
                .font(ToonEdgeTypography.body.weight(.semibold))
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .frame(width: 44, height: 44)
                .background(ToonEdgeColor.panel, in: Circle())
                .overlay(Circle().stroke(ToonEdgeColor.border))
        }
        .buttonStyle(.plain)
        .disabled(isRefreshingUpdates || dependencies.updateRefreshService == nil)
        .accessibilityLabel("Check for new chapters")
    }

    @ViewBuilder
    private var refreshStatus: some View {
        if let refreshMessage {
            TEBanner(
                title: "Update refresh",
                message: refreshMessage,
                systemImage: "arrow.clockwise"
            )
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
            TEBanner(
                title: "No saved reading yet",
                message: "Start with search or paste a chapter link. Your reading progress will appear here later.",
                systemImage: "book.closed"
            )

            TEButton("Start a web reading session", systemImage: "magnifyingglass") {
                router.presentSearch()
            }
        }
    }

    private func section(_ title: String, items: [SeriesSummary], style: HomeSectionStyle) -> some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
            Text(title)
                .font(ToonEdgeTypography.sectionTitle)

            if items.isEmpty {
                TEBanner(title: "Nothing here yet", message: "This section will fill as mock state changes.", systemImage: "tray")
            } else {
                VStack(spacing: ToonEdgeSpacing.small) {
                    ForEach(items) { item in
                        Button {
                            if style == .featured {
                                openContinueReading(item)
                            }
                        } label: {
                            HomeSeriesCard(item: item, style: style)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var continueReadingSection: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
            HStack {
                Text("Continue Reading")
                    .font(ToonEdgeTypography.sectionTitle)
                Spacer()
                if snapshot.showsContinueReadingViewAll {
                    Button("View All") {
                        router.openLibraryRecent()
                    }
                    .font(ToonEdgeTypography.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(ToonEdgeColor.accent)
                }
            }

            if snapshot.continueReading.isEmpty {
                TEBanner(title: "Nothing here yet", message: "This section will fill as mock state changes.", systemImage: "tray")
            } else {
                VStack(spacing: ToonEdgeSpacing.small) {
                    ForEach(snapshot.continueReading) { item in
                        Button {
                            openContinueReading(item)
                        } label: {
                            HomeSeriesCard(item: item, style: .featured)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func openContinueReading(_ item: SeriesSummary) {
        Task {
            let target = await dependencies.libraryLifecycleService?.continueReadingTarget(for: item.id)
            if let target,
               let session = await dependencies.libraryLifecycleService?.readerSession(forChapterID: target.chapterID) {
                var librarySession = session
                librarySession.launchOrigin = .homeContinueReading
                router.presentReader(librarySession)
                return
            }
            router.presentBrowser(.url((target?.sourceURL ?? MockChapter.sample.sourceURL).absoluteString))
        }
    }

    private func reloadSnapshot() async {
        snapshot = await dependencies.libraryService.homeSnapshot()
        hasLoadedSnapshot = true
    }

    private func refreshUpdates() async {
        guard let updateRefreshService = dependencies.updateRefreshService else {
            return
        }

        isRefreshingUpdates = true
        let result = await updateRefreshService.refreshUpdates()
        await reloadSnapshot()
        isRefreshingUpdates = false
        refreshMessage = refreshMessage(for: result)
    }

    private func refreshMessage(for result: LibraryUpdateRefreshResult) -> String {
        if result.failedCount > 0 {
            return "Checked \(result.checkedCount), found \(result.updatedCount) updates, \(result.failedCount) failed."
        }

        return "Checked \(result.checkedCount), found \(result.updatedCount) updates."
    }

    private func chapterTitle(from subtitle: String) -> String {
        if subtitle.hasPrefix("Continue Chapter ") {
            return subtitle.replacingOccurrences(of: "Continue ", with: "")
        }

        if subtitle.hasPrefix("Continue ") {
            return "Chapter \(subtitle.replacingOccurrences(of: "Continue ", with: ""))"
        }

        return MockChapter.sample.title
    }
}

private struct HomeSeriesCard: View {
    let item: SeriesSummary
    let style: HomeSectionStyle

    var body: some View {
        TECard {
            if style == .featured {
                featuredCard
            } else {
                compactCard
            }
        }
    }

    private var featuredCard: some View {
        HStack(alignment: .top, spacing: ToonEdgeSpacing.medium) {
            cover
                .frame(width: 88, height: 124)

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
                titleBlock(titleLineLimit: 2)
                Spacer(minLength: 0)
                ProgressView(value: item.progressPercent)
                    .tint(item.hasUnreadUpdates ? ToonEdgeColor.success : ToonEdgeColor.accent)
            }
            .frame(minHeight: 124)

            Spacer(minLength: 0)

            Image(systemName: "play.fill")
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .padding(.top, ToonEdgeSpacing.medium)
        }
    }

    private var compactCard: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
            HStack(spacing: ToonEdgeSpacing.medium) {
                cover
                    .frame(width: 42, height: 52)

                titleBlock(titleLineLimit: 1)

                Spacer()
                Image(systemName: "chevron.right")
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
            }

            ProgressView(value: item.progressPercent)
                .tint(item.hasUnreadUpdates ? ToonEdgeColor.success : ToonEdgeColor.accent)
        }
    }

    private func titleBlock(titleLineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
            HStack(spacing: ToonEdgeSpacing.small) {
                Text(item.title)
                    .font(ToonEdgeTypography.body.weight(.semibold))
                    .lineLimit(titleLineLimit)
                if item.hasUnreadUpdates {
                    TEChip("New", isActive: true)
                }
            }

            Text(item.subtitle)
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.textSecondary)
        }
    }

    private var cover: some View {
        CachedCoverArtwork(url: item.coverImageURL) {
            coverPlaceholder
        }
        .clipShape(RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: ToonEdgeRadius.small)
                .stroke(ToonEdgeColor.border)
        )
    }

    private var coverPlaceholder: some View {
        RoundedRectangle(cornerRadius: ToonEdgeRadius.small)
            .fill(item.hasUnreadUpdates ? ToonEdgeColor.success.opacity(0.26) : ToonEdgeColor.accentSoft)
            .overlay {
                Image(systemName: item.hasUnreadUpdates ? "sparkle" : "book.pages")
                    .foregroundStyle(item.hasUnreadUpdates ? ToonEdgeColor.success : ToonEdgeColor.accent)
            }
    }
}

private enum HomeSectionStyle {
    case featured
    case compact
}
