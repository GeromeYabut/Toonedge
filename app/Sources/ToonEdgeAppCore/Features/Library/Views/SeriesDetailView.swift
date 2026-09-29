import Foundation
import SwiftUI

enum SeriesDetailMutationOperation: Equatable, Sendable {
    case save
    case stateUpdate
    case remove
}

enum SeriesDetailMutationOutcome: Equatable, Sendable {
    case saved
    case stateUpdated
    case removed
    case failed(SeriesDetailMutationOperation)
    case noOp
}

@MainActor
final class SeriesDetailMutationModel: ObservableObject {
    @Published private(set) var currentDetail: SeriesDetailSnapshot?
    @Published private(set) var failedOperation: SeriesDetailMutationOperation?

    private enum Request: Sendable {
        case save(SeriesDetailSnapshot, LibraryCollectionState)
        case stateUpdate(LibraryCollectionState)
        case remove

        var operation: SeriesDetailMutationOperation {
            switch self {
            case .save: .save
            case .stateUpdate: .stateUpdate
            case .remove: .remove
            }
        }
    }

    private let service: (any LibraryLifecycleManaging)?
    private let interactionFeedback: (any InteractionFeedbackProviding)?
    private var failedRequest: Request?

    init(
        service: (any LibraryLifecycleManaging)?,
        currentDetail: SeriesDetailSnapshot?,
        interactionFeedback: (any InteractionFeedbackProviding)? = nil
    ) {
        self.service = service
        self.currentDetail = currentDetail
        self.interactionFeedback = interactionFeedback
    }

    var canRetry: Bool { failedRequest != nil }

    var failureMessage: String? {
        switch failedOperation {
        case .save: "Could not save this series."
        case .stateUpdate: "Could not update the collection state."
        case .remove: "Could not remove this series."
        case nil: nil
        }
    }

    func setCurrentDetail(_ detail: SeriesDetailSnapshot?) {
        currentDetail = detail
    }

    @discardableResult
    func save(_ detail: SeriesDetailSnapshot, state: LibraryCollectionState) async -> SeriesDetailMutationOutcome {
        await perform(.save(detail, state))
    }

    @discardableResult
    func updateCollectionState(_ state: LibraryCollectionState) async -> SeriesDetailMutationOutcome {
        await perform(.stateUpdate(state))
    }

    @discardableResult
    func removeFromLibrary() async -> SeriesDetailMutationOutcome {
        await perform(.remove)
    }

    @discardableResult
    func retry() async -> SeriesDetailMutationOutcome {
        guard let failedRequest else { return .noOp }
        return await perform(failedRequest)
    }

    private func perform(_ request: Request) async -> SeriesDetailMutationOutcome {
        guard let service, let detail = currentDetail else { return .noOp }

        do {
            let outcome: SeriesDetailMutationOutcome
            switch request {
            case let .save(snapshot, state):
                var input = snapshot.libraryInput
                input.libraryState = state
                try await service.addToLibrary(input, context: .seriesDetail)
                currentDetail = await service.seriesDetail(for: snapshot.id) ?? savedSnapshot(snapshot, state: state)
                outcome = .saved
            case let .stateUpdate(state):
                try await service.updateLibraryState(state, for: detail.id)
                currentDetail = await service.seriesDetail(for: detail.id) ?? stateUpdatedSnapshot(detail, state: state)
                outcome = .stateUpdated
            case .remove:
                try await service.removeFromLibrary(seriesID: detail.id)
                currentDetail = nil
                outcome = .removed
            }
            failedRequest = nil
            failedOperation = nil
            if outcome == .saved || outcome == .removed {
                interactionFeedback?.emit(.operationSucceeded)
            }
            return outcome
        } catch {
            failedRequest = request
            failedOperation = request.operation
            return .failed(request.operation)
        }
    }

    private func savedSnapshot(_ detail: SeriesDetailSnapshot, state: LibraryCollectionState) -> SeriesDetailSnapshot {
        var updated = detail
        updated.isSaved = true
        updated.libraryState = state
        return updated
    }

    private func stateUpdatedSnapshot(_ detail: SeriesDetailSnapshot, state: LibraryCollectionState) -> SeriesDetailSnapshot {
        var updated = detail
        updated.libraryState = state
        return updated
    }
}

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
    @StateObject private var mutationModel: SeriesDetailMutationModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        self._mutationModel = StateObject(
            wrappedValue: SeriesDetailMutationModel(
                service: dependencies.libraryLifecycleService,
                currentDetail: cachedDetail,
                interactionFeedback: dependencies.interactionFeedback
            )
        )
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

    @ViewBuilder
    private func hydratedContent(_ detail: SeriesDetailSnapshot) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        detailHeaderArea(detail)

                        Divider()
                            .overlay(ToonEdgeColor.border)

                        chapterArea(detail)
                    }
                }
                .task(id: detail.chapterListAnchorID) {
                    await scrollToInitialChapter(detail, proxy: proxy)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                detailHeaderArea(detail)

                Divider()
                    .overlay(ToonEdgeColor.border)

                ScrollViewReader { proxy in
                    ScrollView {
                        chapterArea(detail)
                    }
                    .task(id: detail.chapterListAnchorID) {
                        await scrollToInitialChapter(detail, proxy: proxy)
                    }
                }
            }
        }
    }

    private func detailHeaderArea(_ detail: SeriesDetailSnapshot) -> some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
            header(detail)
            cacheStatus
            if let mutationFeedback = mutationModel.failureMessage {
                VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                    TEBanner(title: "Library update failed", message: mutationFeedback, systemImage: "exclamationmark.triangle")
                    if mutationModel.canRetry {
                        Button("Retry") {
                            Task {
                                await mutationModel.retry()
                                publishSuccessfulMutationIfAvailable()
                            }
                        }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("series-detail.mutation-retry")
                    }
                }
            }
        }
        .padding(ToonEdgeSpacing.large)
        .background(ToonEdgeColor.background)
    }

    private func chapterArea(_ detail: SeriesDetailSnapshot) -> some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
            chapterToolbar(detail)
            chapterList(detail)
        }
        .padding(ToonEdgeSpacing.large)
        .padding(.bottom, ToonEdgeSpacing.large)
    }

    private func scrollToInitialChapter(_ detail: SeriesDetailSnapshot, proxy: ScrollViewProxy) async {
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

    private func header(_ detail: SeriesDetailSnapshot) -> some View {
        let layout = SeriesDetailHeaderLayout(snapshot: detail)
        let presentation = SeriesDetailHeaderPresentation(accessibilityText: dynamicTypeSize.isAccessibilitySize)
        return VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
            Group {
                if presentation.arrangement == .vertical {
                    VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
                        cover(for: detail)
                            .frame(width: presentation.coverWidth, height: presentation.coverHeight)
                        headerText(title: layout.title, metadata: layout.metadata, status: detail.status)
                    }
                } else {
                    HStack(alignment: .top, spacing: ToonEdgeSpacing.medium) {
                        cover(for: detail)
                            .frame(width: presentation.coverWidth, height: presentation.coverHeight)
                        headerText(title: layout.title, metadata: layout.metadata, status: detail.status)
                    }
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
        let presentation = SeriesDetailHeaderPresentation(accessibilityText: dynamicTypeSize.isAccessibilitySize)
        return VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
            Group {
                if presentation.arrangement == .vertical {
                    VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
                        seedCover(layout)
                            .frame(width: presentation.coverWidth, height: presentation.coverHeight)
                        headerText(title: layout.title, metadata: layout.metadata, status: layout.status)
                    }
                } else {
                    HStack(alignment: .top, spacing: ToonEdgeSpacing.medium) {
                        seedCover(layout)
                            .frame(width: presentation.coverWidth, height: presentation.coverHeight)
                        headerText(title: layout.title, metadata: layout.metadata, status: layout.status)
                    }
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

    private func headerText(title: String, metadata: String, status: String) -> some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
            Text(status.uppercased())
                .font(ToonEdgeTypography.caption.weight(.semibold))
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .tracking(0.6)

            Text(title)
                .font(ToonEdgeTypography.title)
                .fixedSize(horizontal: false, vertical: true)

            Text(metadata)
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func seedCover(_ layout: SeriesDetailSeedShellLayout) -> some View {
        CachedCoverArtwork(url: layout.coverImageURL) {
            MissingCoverView(title: layout.title)
        }
        .clipShape(RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
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
                        .frame(width: 44, height: 44)
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
                    let utility = ChapterUtilityPresentation(
                        isOpenable: chapter.isOpenable,
                        isGeneratedPlaceholder: chapter.isGeneratedPlaceholder
                    )
                    HStack(spacing: ToonEdgeSpacing.small) {
                        chapterPrimaryAction(chapter)

                        if utility.isVisible {
                            Menu {
                                Button("Open Original Page", systemImage: "safari") {
                                    openOriginal(chapter)
                                }
                                Button("Retain Offline", systemImage: "arrow.down.circle") {
                                    retain(chapter)
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .frame(width: utility.minimumHitSize, height: utility.minimumHitSize)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Chapter \(chapter.chapterLabel) actions")
                            .accessibilityIdentifier("series-detail.chapter-actions.\(chapter.id.uuidString)")
                        }
                    }
                    .contextMenu {
                        if utility.isVisible {
                            Button("Open Original Page", systemImage: "safari") {
                                openOriginal(chapter)
                            }
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

    @ViewBuilder
    private func chapterPrimaryAction(_ chapter: ChapterSummary) -> some View {
        let presentation = ChapterPrimaryActionPresentation(
            isOpenable: chapter.isOpenable,
            isGeneratedPlaceholder: chapter.isGeneratedPlaceholder
        )
        let button = Button {
            open(chapter)
        } label: {
            ChapterRow(chapter: chapter)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(!presentation.isEnabled)

        if presentation.voiceOverActions.isEmpty {
            button
        } else {
            button
                .accessibilityAction(named: "Open Original Page") {
                    openOriginal(chapter)
                }
                .accessibilityAction(named: "Retain Offline") {
                    retain(chapter)
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
        mutationModel.setCurrentDetail(updatedDetail)
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
        guard dependencies.libraryLifecycleService != nil else { return }

        Task {
            if detail.isSaved {
                await mutationModel.removeFromLibrary()
                publishSuccessfulMutationIfAvailable()
            } else {
                saveState = AddToLibraryStatePickerModel.defaultState(for: .seriesDetail)
                pendingSaveDetail = detail
            }
        }
    }

    private func confirmSave(_ detail: SeriesDetailSnapshot, state: LibraryCollectionState) {
        guard dependencies.libraryLifecycleService != nil else { return }
        pendingSaveDetail = nil
        Task {
            await mutationModel.save(detail, state: state)
            publishSuccessfulMutationIfAvailable()
        }
    }

    private func updateLibraryState(_ state: LibraryCollectionState) {
        guard dependencies.libraryLifecycleService != nil else { return }

        Task {
            await mutationModel.updateCollectionState(state)
            publishSuccessfulMutationIfAvailable()
        }
    }

    private func publishSuccessfulMutationIfAvailable() {
        guard mutationModel.failedOperation == nil else { return }
        publishDetail(mutationModel.currentDetail)
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
                if let event = InteractionFeedbackOutcomePolicy.cacheEvent(for: result) {
                    dependencies.interactionFeedback.emit(event)
                }
                publishDetail(await dependencies.libraryService.seriesDetail(for: seriesID))
            } catch {
                cacheFeedback = .failure("Could not retain this chapter offline.")
            }
        }
    }

    private func openOriginal(_ chapter: ChapterSummary) {
        router.openOriginalPage(chapter.sourceURL)
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

struct SeriesDetailHeaderPresentation: Equatable, Sendable {
    enum Arrangement: Equatable, Sendable {
        case horizontal
        case vertical
    }

    var arrangement: Arrangement
    var coverWidth: CGFloat
    var coverHeight: CGFloat
    var primaryActionCount: Int
    var usesStatusChip: Bool

    init(accessibilityText: Bool) {
        self.arrangement = accessibilityText ? .vertical : .horizontal
        self.coverWidth = accessibilityText ? 64 : 80
        self.coverHeight = accessibilityText ? 88 : 112
        self.primaryActionCount = 1
        self.usesStatusChip = false
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

struct ChapterRowPresentation: Equatable, Sendable {
    var primaryStateText: String
    var showsReadCheckmark: Bool
    var showsUpdateMarker: Bool
    var showsRetainedMarker: Bool

    init(
        readState: ChapterReadState,
        progressPercent: Double,
        isNew: Bool,
        isDownloaded: Bool,
        isOpenable: Bool
    ) {
        self.showsUpdateMarker = isNew
        self.showsRetainedMarker = isDownloaded
        guard isOpenable else {
            self.primaryStateText = "Unavailable"
            self.showsReadCheckmark = false
            return
        }

        switch readState {
        case .new:
            self.primaryStateText = "New"
            self.showsReadCheckmark = false
        case .unread:
            self.primaryStateText = "Unread"
            self.showsReadCheckmark = false
        case .inProgress:
            self.primaryStateText = "In Progress, \(Int((progressPercent * 100).rounded()))%"
            self.showsReadCheckmark = false
        case .read:
            self.primaryStateText = "Read"
            self.showsReadCheckmark = true
        }
    }
}

struct ChapterUtilityPresentation: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case openOriginal
        case retainOffline
    }

    var isVisible: Bool { !actions.isEmpty }
    var minimumHitSize: CGFloat { 44 }
    var canOpenOriginal: Bool
    var canRetainOffline: Bool
    var actions: [Action]
    var voiceOverActions: [Action] { actions }

    init(isOpenable: Bool, isGeneratedPlaceholder: Bool = false) {
        let hasDiscoveredTarget = isOpenable && !isGeneratedPlaceholder
        self.canOpenOriginal = hasDiscoveredTarget
        self.canRetainOffline = hasDiscoveredTarget
        self.actions = [
            canOpenOriginal ? .openOriginal : nil,
            canRetainOffline ? .retainOffline : nil
        ].compactMap { $0 }
    }
}

struct ChapterPrimaryActionPresentation: Equatable, Sendable {
    var isEnabled: Bool
    var voiceOverActions: [ChapterUtilityPresentation.Action]

    init(isOpenable: Bool, isGeneratedPlaceholder: Bool) {
        let utility = ChapterUtilityPresentation(
            isOpenable: isOpenable,
            isGeneratedPlaceholder: isGeneratedPlaceholder
        )
        self.isEnabled = isOpenable
        self.voiceOverActions = utility.voiceOverActions
    }
}

private struct ChapterRow: View {
    let chapter: ChapterSummary
    private var presentation: ChapterRowPresentation {
        let progressPercent: Double
        if case let .inProgress(value) = chapter.readState {
            progressPercent = value
        } else {
            progressPercent = 0
        }
        return ChapterRowPresentation(
            readState: chapter.readState,
            progressPercent: progressPercent,
            isNew: chapter.readState == .new,
            isDownloaded: chapter.isDownloaded,
            isOpenable: chapter.isOpenable
        )
    }

    var body: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            stateMark

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text(chapter.title)
                    .font(ToonEdgeTypography.body.weight(.semibold))
                    .foregroundStyle(ToonEdgeColor.textPrimary)

                Text("Chapter \(chapter.chapterLabel)")
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: ToonEdgeSpacing.xsmall) {
                Text(presentation.primaryStateText)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)

                if presentation.showsRetainedMarker {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.success)
                        .accessibilityLabel("Downloaded")
                }
            }
        }
        .padding(.vertical, ToonEdgeSpacing.medium)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(chapter.title), \(presentation.primaryStateText)\(presentation.showsRetainedMarker ? ", retained" : "")")
    }

    private var stateMark: some View {
        Image(systemName: stateIcon)
            .font(ToonEdgeTypography.body.weight(.semibold))
            .foregroundStyle(stateColor)
            .frame(width: 32, height: 32)
            .background(stateColor.opacity(0.16), in: Circle())
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
