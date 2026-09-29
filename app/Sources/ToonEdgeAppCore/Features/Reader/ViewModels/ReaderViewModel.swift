import Foundation

@MainActor
public final class ReaderViewModel: ObservableObject {
    @Published public private(set) var session: MockReaderSession
    @Published public var isChromeVisible: Bool
    @Published public var isSettingsPresented: Bool
    @Published public private(set) var progress: ReaderProgress
    @Published public private(set) var settings: ReaderSettings
    @Published public private(set) var cacheFeedback: CacheActionFeedback?
    @Published public private(set) var libraryFeedback: CacheActionFeedback?
    @Published public private(set) var isSavedToLibrary: Bool
    @Published public private(set) var isSavingToLibrary: Bool
    @Published public private(set) var adjacentLoadState: AdjacentChapterLoadState
    private let progressRepository: (any ReaderProgressStoring)?
    private let cacheMetadataManager: (any CacheMetadataManaging)?
    private let chapterAssetRetainer: (any ChapterAssetRetaining)?
    private let recentReadingRecorder: (any RecentReadingRecording)?
    private let libraryLifecycleService: (any LibraryLifecycleManaging)?
    private let seriesMetadataService: (any SeriesMetadataFetching)?
    private let settingsManager: (any SettingsManaging)?
    private let interactionFeedback: (any InteractionFeedbackProviding)?
    private var hasCompletedInitialRestore: Bool
    private var hasRecordedRecentCacheMetadataForSession: Bool
    private var loadedImageIndices: Set<Int>
    private var visibleImageIndex: Int?
    private var hasAttemptedMetadataRefresh: Bool
    private let adjacentRetryDelayNanoseconds: UInt64
    private var adjacentNavigationOperationID: UUID?

    public init(
        session: MockReaderSession,
        progressRepository: (any ReaderProgressStoring)? = nil,
        cacheMetadataManager: (any CacheMetadataManaging)? = nil,
        chapterAssetRetainer: (any ChapterAssetRetaining)? = nil,
        recentReadingRecorder: (any RecentReadingRecording)? = nil,
        libraryLifecycleService: (any LibraryLifecycleManaging)? = nil,
        seriesMetadataService: (any SeriesMetadataFetching)? = nil,
        settingsManager: (any SettingsManaging)? = nil,
        interactionFeedback: (any InteractionFeedbackProviding)? = nil,
        adjacentRetryDelayNanoseconds: UInt64 = 1_500_000_000
    ) {
        self.session = session
        self.isChromeVisible = false
        self.isSettingsPresented = false
        self.progress = ReaderProgress(currentImageIndex: 0, totalImageCount: session.imageURLs.count)
        self.settings = session.settings
        self.cacheFeedback = nil
        self.libraryFeedback = nil
        self.isSavedToLibrary = false
        self.isSavingToLibrary = false
        self.adjacentLoadState = .idle
        self.progressRepository = progressRepository
        self.cacheMetadataManager = cacheMetadataManager
        self.chapterAssetRetainer = chapterAssetRetainer
        self.recentReadingRecorder = recentReadingRecorder
        self.libraryLifecycleService = libraryLifecycleService
        self.seriesMetadataService = seriesMetadataService
        self.settingsManager = settingsManager
        self.interactionFeedback = interactionFeedback
        self.adjacentRetryDelayNanoseconds = adjacentRetryDelayNanoseconds
        self.hasCompletedInitialRestore = progressRepository == nil
        self.hasRecordedRecentCacheMetadataForSession = false
        self.loadedImageIndices = []
        self.visibleImageIndex = nil
        self.hasAttemptedMetadataRefresh = false
        self.adjacentNavigationOperationID = nil
    }

    public var progressDisplay: String {
        "\(Int((progress.fractionComplete * 100).rounded()))%"
    }

    public var canNavigatePrevious: Bool {
        session.previousChapter != nil
    }

    public var canNavigateNext: Bool {
        session.nextChapter != nil
    }

    public var currentChapterDisplayLabel: String {
        ChapterNumericLabelExtractor.displayLabel(title: session.chapterTitle, sourceURL: session.sourceURL)
    }

    public var canonicalChapterLabel: String {
        ChapterNumericLabelExtractor.label(
            chapterNumber: nil,
            chapterLabel: "",
            title: session.chapterTitle
        ) ?? ChapterNumericLabelExtractor.label(
            chapterNumber: nil,
            chapterLabel: "",
            title: session.sourceURL.path
        ) ?? session.chapterTitle
    }

    public var currentChapterAccessibilityLabel: String {
        "\(session.seriesTitle), \(currentChapterDisplayLabel)"
    }

    public var adjacentFailureMessage: String? {
        adjacentFailure?.message
    }

    public var adjacentFailure: AdjacentChapterLoadFailure? {
        if case let .failed(failure) = adjacentLoadState {
            return failure
        }
        return nil
    }

    public var isAdjacentLoading: Bool {
        if case .loading = adjacentLoadState {
            return true
        }
        return false
    }

    public func replaceSession(_ session: MockReaderSession) async {
        let restoredProgress = await restoredProgress(for: session)
        installSession(session, progress: restoredProgress)
    }

    private func installSession(_ session: MockReaderSession, progress: ReaderProgress) {
        self.session = session
        self.settings = session.settings
        self.progress = progress
        self.isChromeVisible = true
        self.isSettingsPresented = false
        self.hasCompletedInitialRestore = true
        self.hasRecordedRecentCacheMetadataForSession = false
        self.loadedImageIndices = []
        self.visibleImageIndex = nil
        self.adjacentLoadState = .idle
    }

    @discardableResult
    public func navigateAdjacentChapter(
        _ direction: ReaderChapterDirection,
        libraryLifecycleService: (any LibraryLifecycleManaging)?,
        adjacentLoader: (any AdjacentReaderSessionLoading)?
    ) async -> Bool {
        if case .loading = adjacentLoadState { return false }
        let chapter: MockChapter?
        switch direction {
        case .previous:
            chapter = session.previousChapter
        case .next:
            chapter = session.nextChapter
        }
        guard let chapter else { return false }

        let operationID = UUID()
        adjacentNavigationOperationID = operationID
        adjacentLoadState = .loading(direction)
        let originalSession = session

        if var storedSession = await libraryLifecycleService?.readerSession(forSourceURL: chapter.sourceURL),
           !storedSession.imageURLs.isEmpty {
            guard isCurrentAdjacentOperation(operationID) else { return false }
            storedSession = preparedAdjacentSession(storedSession, preserving: originalSession)
            let restoredProgress = await restoredProgress(for: storedSession)
            guard isCurrentAdjacentOperation(operationID) else { return false }
            installSession(storedSession, progress: restoredProgress)
            adjacentNavigationOperationID = nil
            adjacentLoadState = .idle
            interactionFeedback?.emit(.chapterTransitioned)
            return true
        }

        guard let adjacentLoader else {
            guard isCurrentAdjacentOperation(operationID) else { return false }
            adjacentNavigationOperationID = nil
            session = originalSession
            adjacentLoadState = .failed(
                AdjacentChapterLoadFailure(
                    direction: direction,
                    reason: .unavailable,
                    targetURL: chapter.sourceURL
                )
            )
            isChromeVisible = true
            interactionFeedback?.emit(.userActionWarning)
            return false
        }

        do {
            var loadedSession = try await adjacentLoader.loadAdjacentReaderSession(
                from: chapter.sourceURL,
                context: AdjacentReaderSessionLoadContext(currentSession: originalSession, direction: direction)
            )
            guard !loadedSession.imageURLs.isEmpty else {
                throw URLError(.cannotDecodeContentData)
            }
            guard isCurrentAdjacentOperation(operationID) else { return false }
            loadedSession = preparedAdjacentSession(loadedSession, preserving: originalSession)
            let restoredProgress = await restoredProgress(for: loadedSession)
            guard isCurrentAdjacentOperation(operationID) else { return false }
            installSession(loadedSession, progress: restoredProgress)
            adjacentNavigationOperationID = nil
            adjacentLoadState = .idle
            interactionFeedback?.emit(.chapterTransitioned)
            return true
        } catch {
            guard isCurrentAdjacentOperation(operationID) else { return false }
            adjacentNavigationOperationID = nil
            session = originalSession
            let typedError = error as? AdjacentReaderSessionLoadError
            adjacentLoadState = .failed(
                AdjacentChapterLoadFailure(
                    direction: direction,
                    reason: typedError?.reason ?? .unavailable,
                    targetURL: typedError?.targetURL ?? chapter.sourceURL
                )
            )
            isChromeVisible = true
            interactionFeedback?.emit(.userActionWarning)
            return false
        }
    }

    @discardableResult
    public func retryAdjacentChapter(
        libraryLifecycleService: (any LibraryLifecycleManaging)?,
        adjacentLoader: (any AdjacentReaderSessionLoading)?
    ) async -> Bool {
        guard let failure = adjacentFailure else { return false }
        let retryOperationID = UUID()
        adjacentNavigationOperationID = retryOperationID
        adjacentLoadState = .loading(failure.direction)
        if adjacentRetryDelayNanoseconds > 0 {
            do {
                try await Task.sleep(nanoseconds: adjacentRetryDelayNanoseconds)
            } catch {
                if isCurrentAdjacentOperation(retryOperationID) {
                    adjacentNavigationOperationID = nil
                    adjacentLoadState = .failed(failure)
                }
                return false
            }
        }
        guard isCurrentAdjacentOperation(retryOperationID) else { return false }
        adjacentNavigationOperationID = nil
        adjacentLoadState = .idle
        return await navigateAdjacentChapter(
            failure.direction,
            libraryLifecycleService: libraryLifecycleService,
            adjacentLoader: adjacentLoader
        )
    }

    public func cancelAdjacentNavigation() {
        adjacentNavigationOperationID = nil
        adjacentLoadState = .idle
    }

    private func isCurrentAdjacentOperation(_ operationID: UUID) -> Bool {
        adjacentNavigationOperationID == operationID && !Task.isCancelled
    }

    public func toggleChrome() {
        isChromeVisible.toggle()
    }

    public func showSettings() {
        isChromeVisible = true
        isSettingsPresented = true
    }

    public func restoreProgress() async {
        guard let progressRepository else {
            hasCompletedInitialRestore = true
            return
        }

        if let restoredProgress = await progressRepository.progress(for: session.sourceURL) {
            progress = normalizedProgress(from: restoredProgress.currentImageIndex)
        }

        hasCompletedInitialRestore = true
    }

    private func restoredProgress(for session: MockReaderSession) async -> ReaderProgress {
        let imageCount = session.imageURLs.count
        guard let progressRepository,
              let restoredProgress = await progressRepository.progress(for: session.sourceURL) else {
            return ReaderProgress(currentImageIndex: 0, totalImageCount: imageCount)
        }

        let clampedIndex: Int
        if imageCount == 0 {
            clampedIndex = 0
        } else {
            clampedIndex = min(max(0, restoredProgress.currentImageIndex), imageCount - 1)
        }
        return ReaderProgress(currentImageIndex: clampedIndex, totalImageCount: imageCount)
    }

    public func updateProgress(visibleImageIndex: Int) async {
        progress = normalizedProgress(from: visibleImageIndex)

        if hasCompletedInitialRestore, let progressRepository {
            await progressRepository.save(progress, for: session.sourceURL)
            await enrichSessionMetadataIfNeeded()
            try? await recentReadingRecorder?.recordRecentReading(
                RecentReadingInput(
                    seriesID: session.seriesID,
                    chapterID: session.id,
                    seriesTitle: session.seriesTitle,
                    seriesURL: session.seriesURL,
                    sourceDomain: session.sourceDomain,
                    coverImageURL: session.coverImageURL,
                    chapterTitle: session.chapterTitle,
                    chapterLabel: canonicalChapterLabel,
                    sourceURL: session.sourceURL,
                    imageURLs: session.imageURLs,
                    progress: progress
                )
            )
            if !hasRecordedRecentCacheMetadataForSession {
                _ = try? await cacheMetadataManager?.recordCacheMetadata(
                    CacheMetadataInput(
                        sourceURL: session.sourceURL,
                        seriesTitle: session.seriesTitle,
                        chapterTitle: session.chapterTitle,
                        chapterLabel: canonicalChapterLabel,
                        imageCount: session.imageURLs.count,
                        estimatedStorageBytes: 0,
                        retentionState: .recent
                    )
                )
                hasRecordedRecentCacheMetadataForSession = true
            }
        }
    }

    public func markImageVisible(index: Int) async {
        visibleImageIndex = index
        guard loadedImageIndices.contains(index) else {
            return
        }

        await updateProgress(visibleImageIndex: index)
    }

    public func markImageLoaded(index: Int) async {
        loadedImageIndices.insert(index)
        guard visibleImageIndex == index else {
            return
        }

        await updateProgress(visibleImageIndex: index)
    }

    public func retainCurrentChapter() async {
        do {
            let retainedBytes = try await chapterAssetRetainer?.retainAssets(for: session) ?? 0
            guard let result = try await cacheMetadataManager?.recordCacheMetadata(
                CacheMetadataInput(
                    sourceURL: session.sourceURL,
                    seriesTitle: session.seriesTitle,
                    chapterTitle: session.chapterTitle,
                    chapterLabel: canonicalChapterLabel,
                    imageCount: session.imageURLs.count,
                    estimatedStorageBytes: retainedBytes,
                    retentionState: .retained
                )
            ) else {
                return
            }
            cacheFeedback = .success(result)
            if let event = InteractionFeedbackOutcomePolicy.cacheEvent(for: result) {
                interactionFeedback?.emit(event)
            }
        } catch {
            cacheFeedback = .failure("Could not retain this chapter offline.")
        }
    }

    public func clearCacheFeedback() {
        cacheFeedback = nil
    }

    public func clearLibraryFeedback() {
        libraryFeedback = nil
    }

    public func refreshSavedState() async {
        isSavedToLibrary = await libraryLifecycleService?.isSaved(canonicalURL: session.seriesURL) ?? false
    }

    public func saveCurrentSessionToLibrary(
        libraryState: LibraryCollectionState = AddToLibraryStatePickerModel.defaultState(for: .reader)
    ) async {
        guard let libraryLifecycleService, !isSavingToLibrary, !isSavedToLibrary else { return }
        isSavingToLibrary = true
        defer { isSavingToLibrary = false }
        do {
            await enrichSessionMetadataIfNeeded()
            var input = session.libraryInput
            input.libraryState = libraryState
            try await libraryLifecycleService.addToLibrary(input, context: .reader)
            isSavedToLibrary = true
            libraryFeedback = CacheActionFeedback(result: nil, message: "Saved to Library.", isFailure: false)
            interactionFeedback?.emit(.operationSucceeded)
        } catch {
            libraryFeedback = .failure("Could not save this series.")
        }
    }

    private func enrichSessionMetadataIfNeeded() async {
        guard !hasAttemptedMetadataRefresh else { return }
        hasAttemptedMetadataRefresh = true
        guard let metadata = try? await seriesMetadataService?.metadata(for: session.seriesURL) else {
            return
        }
        if let title = metadata.title, !title.isEmpty {
            session.seriesTitle = title
        }
        if let coverImageURL = metadata.coverImageURL {
            session.coverImageURL = coverImageURL
        }
    }

    private func normalizedProgress(from visibleImageIndex: Int) -> ReaderProgress {
        guard !session.imageURLs.isEmpty else {
            return ReaderProgress(currentImageIndex: 0, totalImageCount: 0)
        }

        let clampedIndex = min(max(0, visibleImageIndex), session.imageURLs.count - 1)
        return ReaderProgress(currentImageIndex: clampedIndex, totalImageCount: session.imageURLs.count)
    }

    public func setDisplayMode(_ displayMode: ReaderDisplayMode) {
        settings.displayMode = displayMode
        session.settings = settings
        persistSettings()
    }

    public func setPageSpacingEnabled(_ isEnabled: Bool) {
        settings.isPageSpacingEnabled = isEnabled
        session.settings = settings
        persistSettings()
    }

    public func setBrightnessAid(_ value: Double) {
        settings.brightnessAid = min(0.75, max(0, value))
        session.settings = settings
        persistSettings()
    }

    public func setCanvas(_ canvas: ReaderCanvas) {
        settings.readerCanvas = canvas
        session.settings = settings
        persistSettings()
    }

    private func persistSettings() {
        guard let settingsManager else { return }
        let settings = settings
        Task { await settingsManager.updateSettings(settings) }
    }

    private func preparedAdjacentSession(
        _ adjacentSession: MockReaderSession,
        preserving originalSession: MockReaderSession
    ) -> MockReaderSession {
        var prepared = adjacentSession
        prepared.seriesID = originalSession.seriesID
        prepared.seriesTitle = originalSession.seriesTitle
        prepared.seriesURL = originalSession.seriesURL
        prepared.sourceDomain = originalSession.sourceDomain
        prepared.coverImageURL = originalSession.coverImageURL
        prepared.seriesStatus = originalSession.seriesStatus
        prepared.seriesSynopsis = originalSession.seriesSynopsis
        prepared.launchOrigin = originalSession.launchOrigin
        return prepared
    }
}

private extension MockReaderSession {
    var libraryInput: LibrarySeriesInput {
        let chapterLabel = ChapterNumericLabelExtractor.label(
            chapterNumber: nil,
            chapterLabel: chapterTitle,
            title: sourceURL.absoluteString
        ) ?? chapterTitle

        return LibrarySeriesInput(
            id: seriesID,
            title: seriesTitle,
            canonicalURL: seriesURL,
            sourceDomain: sourceDomain,
            coverImageURL: coverImageURL,
            status: seriesStatus,
            synopsis: seriesSynopsis,
            latestKnownChapterLabel: chapterLabel,
            libraryState: .reading,
            chapters: [
                LibraryChapterInput(
                    title: chapterTitle,
                    chapterLabel: chapterLabel,
                    chapterNumber: Double(chapterLabel),
                    sourceURL: sourceURL,
                    previousChapterURL: previousChapter?.sourceURL,
                    nextChapterURL: nextChapter?.sourceURL,
                    imageURLs: imageURLs,
                    publishedAt: nil
                )
            ]
        )
    }
}
