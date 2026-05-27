import SwiftUI

public struct LibraryView: View {
    private let dependencies: AppDependencies
    @Binding private var router: AppRouter
    @State private var snapshot = LibrarySnapshot(series: [])
    @State private var selectedSegment: LibrarySegment = .recent
    @State private var hasLoadedSnapshot = false
    @State private var isRefreshingUpdates = false
    @State private var refreshMessage: String?
    @State private var navigationPath: [UUID] = []

    public init(dependencies: AppDependencies, router: Binding<AppRouter>) {
        self.dependencies = dependencies
        self._router = router
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
                    header
                    refreshStatus
                    TESegmentedControl(selection: $selectedSegment) { $0.title }
                    summaryBanner
                    content
                }
                .padding(ToonEdgeSpacing.large)
            }
            .navigationTitle("Library")
            .task {
                await reloadSnapshot()
                if let segment = router.consumePendingLibrarySegment() {
                    selectedSegment = segment
                }
                if let seriesID = router.consumePendingLibrarySeriesID() {
                    navigationPath = [seriesID]
                }
            }
            .onChange(of: router.pendingLibrarySegment) { _, pendingSegment in
                guard let pendingSegment else { return }
                selectedSegment = pendingSegment
                _ = router.consumePendingLibrarySegment()
            }
            .onChange(of: router.pendingLibrarySeriesID) { _, pendingSeriesID in
                guard let pendingSeriesID else { return }
                navigationPath = [pendingSeriesID]
                _ = router.consumePendingLibrarySeriesID()
            }
            .refreshable {
                await refreshUpdates()
            }
            .navigationDestination(for: UUID.self) { seriesID in
                SeriesDetailView(seriesID: seriesID, dependencies: dependencies, router: $router)
            }
            .toonEdgeScreen()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text("Collection")
                    .font(ToonEdgeTypography.title)
                Text("Reading progress and saved titles")
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
            }

            Spacer()

            Button {
                Task {
                    await refreshUpdates()
                }
            } label: {
                Image(systemName: isRefreshingUpdates ? "hourglass" : "arrow.clockwise")
                    .font(ToonEdgeTypography.body.weight(.semibold))
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(ToonEdgeColor.panel, in: Circle())
                    .overlay(Circle().stroke(ToonEdgeColor.border))
            }
            .buttonStyle(.plain)
            .disabled(isRefreshingUpdates || dependencies.updateRefreshService == nil)
            .accessibilityLabel("Check for new chapters")
        }
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

    private var summaryBanner: some View {
        let visible = snapshot.series(for: selectedSegment)
        let updates = visible.filter(\.hasUnreadUpdates).count
        let message = updates > 0
            ? "\(updates) with new chapters"
            : "\(visible.count) saved \(visible.count == 1 ? "title" : "titles")"

        return TEBanner(
            title: "\(selectedSegment.title) Library",
            message: message,
            systemImage: updates > 0 ? "bell.badge" : "chart.line.uptrend.xyaxis"
        )
    }

    private func reloadSnapshot() async {
        snapshot = await dependencies.libraryService.librarySnapshot()
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

    @ViewBuilder
    private var content: some View {
        let visible = snapshot.series(for: selectedSegment)

        if hasLoadedSnapshot && visible.isEmpty {
            TEBanner(
                title: "Nothing in \(selectedSegment.title)",
                message: "Series will appear here as reading and collection state changes.",
                systemImage: "tray"
            )
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: ToonEdgeSpacing.medium)],
                spacing: ToonEdgeSpacing.medium
            ) {
                ForEach(visible) { series in
                    NavigationLink(value: series.id) {
                        SeriesCard(series: series)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SeriesCard: View {
    let series: LibrarySeriesSummary

    var body: some View {
        TECard {
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
                cover
                    .aspectRatio(0.72, contentMode: .fit)

                VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                    HStack(alignment: .top, spacing: ToonEdgeSpacing.small) {
                        Text(series.title)
                            .font(ToonEdgeTypography.body.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }

                    Text(metadata)
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                        .lineLimit(1)
                }

                ProgressView(value: series.progressPercent)
                    .tint(progressTint)

                HStack(spacing: ToonEdgeSpacing.xsmall) {
                    if series.hasUnreadUpdates {
                        TEChip("New", isActive: true)
                    }

                    if series.isCompleted {
                        TEChip("Complete")
                    } else if let latestChapterLabel = series.latestChapterLabel {
                        TEChip("Ch. \(latestChapterLabel)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var cover: some View {
        CachedCoverArtwork(url: series.coverImageURL) {
            MissingCoverView(title: series.title)
        }
        .clipShape(RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: ToonEdgeRadius.small)
                .stroke(ToonEdgeColor.border)
        )
    }

    private var metadata: String {
        if let currentChapterLabel = series.currentChapterLabel, !series.isCompleted {
            "Continue \(currentChapterLabel) • \(series.chapterSummaryText)"
        } else {
            series.chapterSummaryText
        }
    }

    private var progressTint: Color {
        series.hasUnreadUpdates ? ToonEdgeColor.success : ToonEdgeColor.accent
    }
}

private struct MissingCoverView: View {
    let title: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ToonEdgeColor.accentSoft, ToonEdgeColor.panel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: ToonEdgeSpacing.small) {
                Image(systemName: "book.pages")
                    .font(.title2)
                    .foregroundStyle(ToonEdgeColor.accent)

                Text(initials)
                    .font(ToonEdgeTypography.title)
                    .foregroundStyle(ToonEdgeColor.textPrimary)
            }
        }
    }

    private var initials: String {
        title
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

private struct SeriesDetailView: View {
    let seriesID: UUID
    let dependencies: AppDependencies
    @Binding var router: AppRouter
    @State private var detail: SeriesDetailSnapshot?
    @State private var sort: ChapterListSort = .newestFirst
    @State private var hasLoaded = false
    @State private var cacheFeedback: CacheActionFeedback?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
                if let detail {
                    header(detail)
                    cacheStatus
                    chapterToolbar(detail)
                    chapterList(detail)
                } else if hasLoaded {
                    TEBanner(
                        title: "Series unavailable",
                        message: "This saved title could not be loaded from the mock repository.",
                        systemImage: "exclamationmark.triangle"
                    )
                } else {
                    TEBanner(title: "Loading series", message: "Preparing chapter state.", systemImage: "hourglass")
                }
            }
            .padding(ToonEdgeSpacing.large)
        }
        .navigationTitle("")
        .task {
            detail = await dependencies.libraryService.seriesDetail(for: seriesID)
            hasLoaded = true
        }
        .toonEdgeScreen()
    }

    private func header(_ detail: SeriesDetailSnapshot) -> some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
            HStack(alignment: .top, spacing: ToonEdgeSpacing.medium) {
                cover(for: detail)
                    .frame(width: 96, height: 132)

                VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                    HStack(spacing: ToonEdgeSpacing.small) {
                        TEChip(detail.status, isActive: detail.hasUnreadUpdates)
                        TEChip(detail.isSaved ? "Saved" : "Follow")
                    }

                    Text(detail.title)
                        .font(ToonEdgeTypography.title)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(detail.sourceDomain) • \(detail.chaptersRead)/\(detail.totalKnownChapters ?? detail.chapters.count) chapters")
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                }
            }

            Text(detail.synopsis)
                .font(ToonEdgeTypography.body)
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TEButton(detail.primaryActionTitle, systemImage: "play.fill") {
                open(detail.primaryChapter)
            }
            .disabled(detail.primaryChapter == nil)
        }
    }

    @ViewBuilder
    private var cacheStatus: some View {
        if let cacheFeedback {
            TEBanner(
                title: cacheFeedback.isFailure ? "Cache action failed" : "Cache updated",
                message: cacheFeedback.message,
                systemImage: cacheFeedback.isFailure ? "exclamationmark.triangle" : "checkmark.circle"
            )
        }
    }

    private func chapterToolbar(_ detail: SeriesDetailSnapshot) -> some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
            HStack {
                Text("Chapters")
                    .font(ToonEdgeTypography.sectionTitle)
                Spacer()
                Menu {
                    Button(detail.isSaved ? "Remove from Library" : "Add to Library") {
                        toggleLibraryMembership(detail)
                    }

                    Divider()

                    Button("Mark Reading") {
                        updateLibraryState(.reading)
                    }
                    Button("Mark Planned") {
                        updateLibraryState(.planned)
                    }
                    Button("Mark Completed") {
                        updateLibraryState(.completed)
                    }
                } label: {
                    Image(systemName: detail.isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(ToonEdgeColor.accent)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(detail.isSaved ? "Saved series" : "Save series")
            }

            TESegmentedControl(selection: $sort) { $0.title }
        }
    }

    @ViewBuilder
    private func chapterList(_ detail: SeriesDetailSnapshot) -> some View {
        let chapters = detail.chapters(sortedBy: sort)

        if chapters.isEmpty {
            TEBanner(title: "No chapters yet", message: "Chapter metadata will appear here when available.", systemImage: "list.bullet")
        } else {
            VStack(spacing: ToonEdgeSpacing.small) {
                ForEach(chapters) { chapter in
                    Button {
                        open(chapter)
                    } label: {
                        ChapterRow(chapter: chapter)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Retain Offline", systemImage: "arrow.down.circle") {
                            retain(chapter)
                        }
                    }
                }
            }
        }
    }

    private func cover(for detail: SeriesDetailSnapshot) -> some View {
        CachedCoverArtwork(url: detail.coverImageURL) {
            MissingCoverView(title: detail.title)
        }
        .clipShape(RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
        .overlay(RoundedRectangle(cornerRadius: ToonEdgeRadius.small).stroke(ToonEdgeColor.border))
    }

    private func open(_ chapter: ChapterSummary?) {
        guard let chapter else { return }

        Task {
            if let directSession = await dependencies.libraryLifecycleService?.readerSession(forChapterID: chapter.id) {
                var librarySession = directSession
                librarySession.launchOrigin = .library(seriesID: seriesID)
                router.presentReader(librarySession)
                return
            }
            router.presentBrowser(.url(chapter.sourceURL.absoluteString))
        }
    }

    private func toggleLibraryMembership(_ detail: SeriesDetailSnapshot) {
        guard let lifecycleService = dependencies.libraryLifecycleService else { return }

        Task {
            if detail.isSaved {
                try? await lifecycleService.removeFromLibrary(seriesID: detail.id)
                self.detail = nil
            } else {
                try? await lifecycleService.addToLibrary(detail.libraryInput, context: .seriesDetail)
                self.detail = await dependencies.libraryService.seriesDetail(for: detail.id)
            }
        }
    }

    private func updateLibraryState(_ state: LibraryCollectionState) {
        guard let lifecycleService = dependencies.libraryLifecycleService else { return }

        Task {
            try? await lifecycleService.updateLibraryState(state, for: seriesID)
            detail = await dependencies.libraryService.seriesDetail(for: seriesID)
        }
    }

    private func retain(_ chapter: ChapterSummary) {
        Task {
            do {
                let result = try await dependencies.cacheMetadataService.updateCacheRetention(
                    for: chapter.sourceURL,
                    retentionState: .retained,
                    cachedAt: Date()
                )
                cacheFeedback = .success(result)
                detail = await dependencies.libraryService.seriesDetail(for: seriesID)
            } catch {
                cacheFeedback = .failure("Could not retain this chapter offline.")
            }
        }
    }
}

private extension SeriesDetailSnapshot {
    var libraryInput: LibrarySeriesInput {
        LibrarySeriesInput(
            id: id,
            title: title,
            canonicalURL: canonicalURL,
            sourceDomain: sourceDomain,
            coverImageURL: coverImageURL,
            status: status,
            synopsis: synopsis,
            latestKnownChapterLabel: chapters.max { lhs, rhs in
                (lhs.chapterNumber ?? .leastNonzeroMagnitude) < (rhs.chapterNumber ?? .leastNonzeroMagnitude)
            }?.chapterLabel,
            libraryState: libraryState,
            chapters: chapters.map {
                LibraryChapterInput(
                    id: $0.id,
                    title: $0.title,
                    chapterLabel: $0.chapterLabel,
                    chapterNumber: $0.chapterNumber,
                    sourceURL: $0.sourceURL,
                    imageURLs: [],
                    publishedAt: $0.publishedAt
                )
            }
        )
    }

    private var canonicalURL: URL {
        chapters.first?.sourceURL.deletingLastPathComponent()
            ?? URL(string: "https://\(sourceDomain)")!
    }
}

private struct ChapterRow: View {
    let chapter: ChapterSummary

    var body: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            stateMark

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text(chapter.title)
                    .font(ToonEdgeTypography.body.weight(.semibold))
                    .foregroundStyle(ToonEdgeColor.textPrimary)

                Text(subtitle)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: ToonEdgeSpacing.xsmall) {
                TEChip(chapter.readState.displayLabel, isActive: isPrimaryState)

                if chapter.isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.success)
                        .accessibilityLabel("Downloaded")
                }
            }
        }
        .padding(ToonEdgeSpacing.large)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: ToonEdgeRadius.medium)
                .stroke(rowBorder)
        )
    }

    private var stateMark: some View {
        Image(systemName: stateIcon)
            .font(ToonEdgeTypography.body.weight(.semibold))
            .foregroundStyle(stateColor)
            .frame(width: 32, height: 32)
            .background(stateColor.opacity(0.16), in: Circle())
    }

    private var subtitle: String {
        if let downloadLabel = chapter.downloadLabel {
            "Chapter \(chapter.chapterLabel) • \(downloadLabel)"
        } else {
            "Chapter \(chapter.chapterLabel)"
        }
    }

    private var isPrimaryState: Bool {
        switch chapter.readState {
        case .new, .inProgress:
            true
        case .unread, .read:
            false
        }
    }

    private var rowBackground: Color {
        switch chapter.readState {
        case .new:
            ToonEdgeColor.success.opacity(0.14)
        case .inProgress:
            ToonEdgeColor.accentSoft
        case .unread:
            ToonEdgeColor.elevated
        case .read:
            ToonEdgeColor.panel
        }
    }

    private var rowBorder: Color {
        chapter.isDownloaded ? ToonEdgeColor.success.opacity(0.55) : ToonEdgeColor.border
    }

    private var stateColor: Color {
        switch chapter.readState {
        case .new:
            ToonEdgeColor.success
        case .inProgress:
            ToonEdgeColor.accent
        case .unread:
            ToonEdgeColor.textSecondary
        case .read:
            ToonEdgeColor.textPrimary.opacity(0.72)
        }
    }

    private var stateIcon: String {
        switch chapter.readState {
        case .new:
            "sparkle"
        case .inProgress:
            "play.fill"
        case .unread:
            "circle"
        case .read:
            "checkmark.circle.fill"
        }
    }
}
