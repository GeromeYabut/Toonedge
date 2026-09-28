import Foundation
import SwiftUI

struct SeriesDetailSeedShellLayout: Equatable, Sendable {
    var title: String
    var metadata: String
    var coverImageURL: URL?
    var status: String
    var hasUnreadUpdates: Bool
    var showsLoadingBanner: Bool
    var exposesContinueAction: Bool
    var primaryChapter: ChapterSummary?
    var primaryActionTitle: String?

    init(summary: LibrarySeriesSummary) {
        self.title = summary.title
        self.metadata = "\(summary.sourceDomain) • \(summary.chapterSummaryText)"
        self.coverImageURL = summary.coverImageURL
        self.status = summary.libraryState.title
        self.hasUnreadUpdates = summary.hasUnreadUpdates
        self.showsLoadingBanner = false
        self.primaryChapter = summary.resumeTarget?.chapter
        self.primaryActionTitle = summary.resumeTarget?.actionTitle
        self.exposesContinueAction = summary.resumeTarget != nil
    }
}

struct SeriesDetailChapterOpenRoute: Equatable, Sendable {
    var chapter: ChapterSummary
    var seriesID: UUID

    var browserStartPoint: BrowserStartPoint {
        .url(chapter.sourceURL.absoluteString)
    }

    var browserReaderLaunchOrigin: ReaderLaunchOrigin {
        .library(seriesID: seriesID)
    }
}

struct SeriesDetailCoverLayout: Equatable, Sendable {
    var coverImageURL: URL?
    var usesPlaceholder: Bool

    init(coverImageURL: URL?) {
        self.coverImageURL = coverImageURL
        self.usesPlaceholder = coverImageURL == nil
    }
}

struct SeriesDetailView: View {
    let seriesID: UUID
    let seedSummary: LibrarySeriesSummary?
    let dependencies: AppDependencies
    let onDetailHydrated: @MainActor (SeriesDetailSnapshot?) -> Void
    @Binding var router: AppRouter
    @State private var detail: SeriesDetailSnapshot?
    @State private var hasLoaded = false
    @State private var hasAttemptedChapterIndexRefresh = false
    @State private var cacheFeedback: CacheActionFeedback?
    @State private var pendingSaveDetail: SeriesDetailSnapshot?
    @State private var saveState = AddToLibraryStatePickerModel.defaultState(for: .seriesDetail)

    init(
        seriesID: UUID,
        seedSummary: LibrarySeriesSummary? = nil,
        cachedDetail: SeriesDetailSnapshot? = nil,
        dependencies: AppDependencies,
        router: Binding<AppRouter>,
        onDetailHydrated: @escaping @MainActor (SeriesDetailSnapshot?) -> Void = { _ in }
    ) {
        self.seriesID = seriesID
        self.seedSummary = seedSummary
        self.dependencies = dependencies
        self._router = router
        self.onDetailHydrated = onDetailHydrated
        self._detail = State(initialValue: cachedDetail)
    }

    var body: some View {
        content
            .navigationTitle("")
            .task {
                await reloadDetail()
            }
            .task(id: detail?.id) {
                guard detail != nil else { return }
                await refreshChapterIndexIfAvailable()
            }
            .onChange(of: router.presentedReader) { oldValue, newValue in
                guard oldValue != nil, newValue == nil else { return }
                Task {
                    await reloadDetail()
                }
            }
            .sheet(item: $pendingSaveDetail) { detail in
                AddToLibraryStatePickerView(
                    title: detail.title,
                    selectedState: $saveState,
                    context: .seriesDetail,
                    confirm: { state in
                        confirmSave(detail, state: state)
                    },
                    cancel: {
                        pendingSaveDetail = nil
                    }
                )
            }
            .toonEdgeScreen()
    }

    @ViewBuilder
    private var content: some View {
        if let detail {
            hydratedContent(detail)
        } else if let seedSummary {
            ScrollView {
                seedShell(seedSummary)
                    .padding(ToonEdgeSpacing.large)
            }
        } else if hasLoaded {
            ScrollView {
                TEBanner(
                    title: "Series unavailable",
                    message: "This saved title could not be loaded from the mock repository.",
                    systemImage: "exclamationmark.triangle"
                )
                .padding(ToonEdgeSpacing.large)
            }
        } else {
            ScrollView {
                TEBanner(title: "Loading series", message: "Preparing chapter state.", systemImage: "hourglass")
                    .padding(ToonEdgeSpacing.large)
            }
        }
    }

    private func hydratedContent(_ detail: SeriesDetailSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
                header(detail)
                cacheStatus
            }
            .padding(ToonEdgeSpacing.large)
            .background(ToonEdgeColor.background)

            Divider()
                .overlay(ToonEdgeColor.border)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
                        chapterToolbar(detail)
                        chapterList(detail)
                    }
                    .padding(ToonEdgeSpacing.large)
                    .padding(.bottom, ToonEdgeSpacing.large)
                }
                .task(id: detail.chapterListAnchorID) {
                    let behavior = SeriesDetailInitialScrollBehavior(anchorID: detail.chapterListAnchorID)
                    guard behavior.shouldScroll, let anchorID = behavior.anchorID else { return }
                    await Task.yield()
                    var transaction = Transaction()
                    transaction.disablesAnimations = behavior.disablesAnimation
                    transaction.animation = nil
                    withTransaction(transaction) {
                        proxy.scrollTo(anchorID, anchor: .center)
                    }
                }
            }
        }
    }

    private func header(_ detail: SeriesDetailSnapshot) -> some View {
        let layout = SeriesDetailHeaderLayout(snapshot: detail)
        return VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
            HStack(alignment: .top, spacing: ToonEdgeSpacing.medium) {
                cover(for: detail)
                    .frame(width: 96, height: 132)

                VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                    HStack(spacing: ToonEdgeSpacing.small) {
                        TEChip(detail.status, isActive: detail.hasUnreadUpdates)
                        TEChip(detail.isSaved ? "Saved" : "Follow")
                    }

                    Text(layout.title)
                        .font(ToonEdgeTypography.title)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(layout.metadata)
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                }
            }

            TEButton(layout.primaryActionTitle, systemImage: "play.fill") {
                open(detail.primaryChapter)
            }
            .disabled(detail.primaryChapter == nil)
        }
    }

    private func seedShell(_ summary: LibrarySeriesSummary) -> some View {
        let layout = SeriesDetailSeedShellLayout(summary: summary)
        return VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
            HStack(alignment: .top, spacing: ToonEdgeSpacing.medium) {
                CachedCoverArtwork(url: layout.coverImageURL) {
                    MissingCoverView(title: layout.title)
                }
                .frame(width: 96, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
                .overlay(RoundedRectangle(cornerRadius: ToonEdgeRadius.small).stroke(ToonEdgeColor.border))

                VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                    HStack(spacing: ToonEdgeSpacing.small) {
                        TEChip(layout.status, isActive: layout.hasUnreadUpdates)
                        TEChip("Saved")
                    }

                    Text(layout.title)
                        .font(ToonEdgeTypography.title)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(layout.metadata)
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                }
            }

            if let primaryChapter = layout.primaryChapter,
               let primaryActionTitle = layout.primaryActionTitle {
                TEButton(primaryActionTitle, systemImage: "play.fill") {
                    open(primaryChapter)
                }
            }
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
                    Button("Mark Dropped") {
                        updateLibraryState(.dropped)
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
        }
    }

    @ViewBuilder
    private func chapterList(_ detail: SeriesDetailSnapshot) -> some View {
        let chapters = detail.chapterList(for: .all)

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
                    .disabled(!chapter.isOpenable)
                    .contextMenu {
                        if chapter.isOpenable {
                            Button("Retain Offline", systemImage: "arrow.down.circle") {
                                retain(chapter)
                            }
                        }
                    }
                    .id(chapter.id)
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

    private func reloadDetail() async {
        let loadedDetail = await dependencies.libraryService.seriesDetail(for: seriesID)
        hasLoaded = true
        publishDetail(loadedDetail)
    }

    private func publishDetail(_ updatedDetail: SeriesDetailSnapshot?) {
        detail = updatedDetail
        onDetailHydrated(SeriesDetailCachePolicy(detail: updatedDetail).cachedDetail)
    }

    private func refreshChapterIndexIfAvailable() async {
        guard SeriesDetailRefreshBehavior.shouldAttemptRefresh(
            detail: detail,
            hasAttemptedChapterIndexRefresh: hasAttemptedChapterIndexRefresh,
            chapterIndexRefreshService: dependencies.chapterIndexRefreshService
        ) else {
            return
        }

        hasAttemptedChapterIndexRefresh = true
        let outcome = await dependencies.chapterIndexRefreshService?.refreshChapterIndex(for: seriesID)
        if SeriesDetailRefreshBehavior.shouldReloadDetail(after: outcome) {
            await reloadDetail()
        }
    }

    private func open(_ chapter: ChapterSummary?) {
        guard let chapter, chapter.isOpenable else { return }

        Task {
            if let directSession = await dependencies.libraryLifecycleService?.readerSession(forChapterID: chapter.id) {
                var librarySession = directSession
                librarySession.launchOrigin = .library(seriesID: seriesID)
                router.presentReader(librarySession)
                return
            }
            let route = SeriesDetailChapterOpenRoute(chapter: chapter, seriesID: seriesID)
            router.presentBrowser(route.browserStartPoint, readerLaunchOrigin: route.browserReaderLaunchOrigin)
        }
    }

    private func toggleLibraryMembership(_ detail: SeriesDetailSnapshot) {
        guard let lifecycleService = dependencies.libraryLifecycleService else { return }

        Task {
            if detail.isSaved {
                try? await lifecycleService.removeFromLibrary(seriesID: detail.id)
                publishDetail(nil)
            } else {
                saveState = AddToLibraryStatePickerModel.defaultState(for: .seriesDetail)
                pendingSaveDetail = detail
            }
        }
    }

    private func confirmSave(_ detail: SeriesDetailSnapshot, state: LibraryCollectionState) {
        guard let lifecycleService = dependencies.libraryLifecycleService else { return }
        pendingSaveDetail = nil
        var input = detail.libraryInput
        input.libraryState = state

        Task {
            try? await lifecycleService.addToLibrary(input, context: .seriesDetail)
            publishDetail(await dependencies.libraryService.seriesDetail(for: detail.id))
        }
    }

    private func updateLibraryState(_ state: LibraryCollectionState) {
        guard let lifecycleService = dependencies.libraryLifecycleService else { return }

        Task {
            try? await lifecycleService.updateLibraryState(state, for: seriesID)
            publishDetail(await dependencies.libraryService.seriesDetail(for: seriesID))
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
                publishDetail(await dependencies.libraryService.seriesDetail(for: seriesID))
            } catch {
                cacheFeedback = .failure("Could not retain this chapter offline.")
            }
        }
    }
}

struct SeriesDetailHeaderLayout: Equatable, Sendable {
    var title: String
    var metadata: String
    var synopsisText: String?
    var primaryActionTitle: String

    init(snapshot: SeriesDetailSnapshot) {
        self.title = snapshot.title
        self.metadata = "\(snapshot.sourceDomain) • \(snapshot.chaptersRead)/\(snapshot.totalKnownChapters ?? snapshot.chapters.count) chapters"
        self.synopsisText = nil
        self.primaryActionTitle = snapshot.primaryActionTitle
    }
}

struct SeriesDetailPageLayout: Equatable, Sendable {
    enum StateKind: Equatable, Sendable {
        case hydrated
        case seeded
        case loading
        case unavailable
    }

    var stateKind: StateKind
    var keepsHeaderFixed: Bool
    var scrollsChaptersIndependently: Bool
    var keepsPrimaryActionVisible: Bool

    init(detail: SeriesDetailSnapshot?, seedSummary: LibrarySeriesSummary?, hasLoaded: Bool) {
        if let detail {
            self.stateKind = .hydrated
            self.keepsHeaderFixed = true
            self.scrollsChaptersIndependently = true
            self.keepsPrimaryActionVisible = detail.primaryChapter != nil
        } else if seedSummary != nil {
            self.stateKind = .seeded
            self.keepsHeaderFixed = true
            self.scrollsChaptersIndependently = false
            self.keepsPrimaryActionVisible = false
        } else if hasLoaded {
            self.stateKind = .unavailable
            self.keepsHeaderFixed = false
            self.scrollsChaptersIndependently = false
            self.keepsPrimaryActionVisible = false
        } else {
            self.stateKind = .loading
            self.keepsHeaderFixed = false
            self.scrollsChaptersIndependently = false
            self.keepsPrimaryActionVisible = false
        }
    }
}

struct SeriesDetailChapterSectionLayout: Equatable, Sendable {
    var showsSegmentedControl: Bool
    var defaultMode: SeriesDetailChapterListMode

    init() {
        self.showsSegmentedControl = false
        self.defaultMode = .all
    }
}

struct SeriesDetailInitialScrollBehavior: Equatable, Sendable {
    var anchorID: UUID?
    var delayMilliseconds: Int
    var disablesAnimation: Bool

    init(anchorID: UUID?) {
        self.anchorID = anchorID
        self.delayMilliseconds = 0
        self.disablesAnimation = anchorID != nil
    }

    var shouldScroll: Bool {
        anchorID != nil
    }
}

struct SeriesDetailRefreshBehavior {
    static func shouldAttemptRefresh(
        detail: SeriesDetailSnapshot?,
        hasAttemptedChapterIndexRefresh: Bool,
        chapterIndexRefreshService: (any SeriesChapterIndexRefreshing)?
    ) -> Bool {
        detail != nil && !hasAttemptedChapterIndexRefresh && chapterIndexRefreshService != nil
    }

    static func shouldReloadDetail(after outcome: ChapterIndexRefreshOutcome?) -> Bool {
        outcome?.didRefresh == true
    }
}

struct SeriesDetailStartupPlan: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case loadLocalDetail
        case startBackgroundRefresh
        case idle
    }

    var localDetailLoaded: Bool
    var refreshAttempted: Bool

    var nextPhase: Phase {
        if !localDetailLoaded {
            return .loadLocalDetail
        }

        if !refreshAttempted {
            return .startBackgroundRefresh
        }

        return .idle
    }
}

struct SeriesDetailEntryLayout: Equatable, Sendable {
    enum VisibleState: Equatable, Sendable {
        case hydratedDetail
        case seededShell
        case loading
        case unavailable
    }

    var visibleState: VisibleState
    var exposesContinueAction: Bool
    var startsBackgroundRefresh: Bool

    init(
        cachedDetail: SeriesDetailSnapshot?,
        seedSummary: LibrarySeriesSummary?,
        hasLoaded: Bool
    ) {
        if let cachedDetail {
            self.visibleState = .hydratedDetail
            self.exposesContinueAction = cachedDetail.primaryChapter != nil
            self.startsBackgroundRefresh = true
        } else if seedSummary != nil {
            self.visibleState = .seededShell
            self.exposesContinueAction = false
            self.startsBackgroundRefresh = false
        } else if hasLoaded {
            self.visibleState = .unavailable
            self.exposesContinueAction = false
            self.startsBackgroundRefresh = false
        } else {
            self.visibleState = .loading
            self.exposesContinueAction = false
            self.startsBackgroundRefresh = false
        }
    }
}

struct SeriesDetailCachePolicy: Equatable, Sendable {
    var cachedDetail: SeriesDetailSnapshot?
    var clearsCachedDetail: Bool

    init(detail: SeriesDetailSnapshot?) {
        self.cachedDetail = detail
        self.clearsCachedDetail = detail == nil
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
        if !chapter.isOpenable {
            return "Chapter \(chapter.chapterLabel) • Unavailable"
        }

        if let downloadLabel = chapter.downloadLabel {
            return "Chapter \(chapter.chapterLabel) • \(downloadLabel)"
        } else {
            return "Chapter \(chapter.chapterLabel)"
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
