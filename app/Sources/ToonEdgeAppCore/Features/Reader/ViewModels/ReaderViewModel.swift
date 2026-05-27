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
    @Published public private(set) var adjacentLoadState: AdjacentChapterLoadState
    private let progressRepository: (any ReaderProgressStoring)?
    private let cacheMetadataManager: (any CacheMetadataManaging)?
    private let recentReadingRecorder: (any RecentReadingRecording)?
    private let libraryLifecycleService: (any LibraryLifecycleManaging)?
    private let seriesMetadataService: (any SeriesMetadataFetching)?
    private var hasCompletedInitialRestore: Bool
    private var hasRecordedRecentCacheMetadataForSession: Bool
    private var loadedImageIndices: Set<Int>
    private var visibleImageIndex: Int?
    private var hasAttemptedMetadataRefresh: Bool

    public init(
        session: MockReaderSession,
        progressRepository: (any ReaderProgressStoring)? = nil,
        cacheMetadataManager: (any CacheMetadataManaging)? = nil,
        recentReadingRecorder: (any RecentReadingRecording)? = nil,
        libraryLifecycleService: (any LibraryLifecycleManaging)? = nil,
        seriesMetadataService: (any SeriesMetadataFetching)? = nil
    ) {
        self.session = session
        self.isChromeVisible = false
        self.isSettingsPresented = false
        self.progress = ReaderProgress(currentImageIndex: 0, totalImageCount: session.imageURLs.count)
        self.settings = session.settings
        self.cacheFeedback = nil
        self.libraryFeedback = nil
        self.isSavedToLibrary = false
        self.adjacentLoadState = .idle
        self.progressRepository = progressRepository
        self.cacheMetadataManager = cacheMetadataManager
        self.recentReadingRecorder = recentReadingRecorder
        self.libraryLifecycleService = libraryLifecycleService
        self.seriesMetadataService = seriesMetadataService
        self.hasCompletedInitialRestore = progressRepository == nil
        self.hasRecordedRecentCacheMetadataForSession = false
        self.loadedImageIndices = []
        self.visibleImageIndex = nil
        self.hasAttemptedMetadataRefresh = false
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
        conciseChapterLabel(from: session.chapterTitle)
    }

    public var currentChapterAccessibilityLabel: String {
        "\(session.seriesTitle), \(currentChapterDisplayLabel)"
    }

    public var adjacentFailureMessage: String? {
        if case let .failed(_, message) = adjacentLoadState {
            return message
        }
        return nil
    }

    public func replaceSession(_ session: MockReaderSession) async {
        self.session = session
        self.settings = session.settings
        self.progress = ReaderProgress(currentImageIndex: 0, totalImageCount: session.imageURLs.count)
        self.isChromeVisible = true
        self.isSettingsPresented = false
        self.hasCompletedInitialRestore = progressRepository == nil
        self.hasRecordedRecentCacheMetadataForSession = false
        self.loadedImageIndices = []
        self.visibleImageIndex = nil
        self.adjacentLoadState = .idle
        await restoreProgress()
    }

    public func navigateAdjacentChapter(
        _ direction: ReaderChapterDirection,
        libraryLifecycleService: (any LibraryLifecycleManaging)?,
        adjacentLoader: (any AdjacentReaderSessionLoading)?
    ) async {
        guard case .idle = adjacentLoadState else { return }
        let chapter: MockChapter?
        switch direction {
        case .previous:
            chapter = session.previousChapter
        case .next:
            chapter = session.nextChapter
        }
        guard let chapter else { return }

        adjacentLoadState = .loading(direction)
        let originalSession = session

        if var storedSession = await libraryLifecycleService?.readerSession(forSourceURL: chapter.sourceURL),
           !storedSession.imageURLs.isEmpty {
            storedSession = preparedAdjacentSession(storedSession, preserving: originalSession)
            await replaceSession(storedSession)
            adjacentLoadState = .idle
            return
        }

        guard let adjacentLoader else {
            session = originalSession
            adjacentLoadState = .failed(direction, message: direction.failureMessage)
            isChromeVisible = true
            return
        }

        do {
            var loadedSession = try await adjacentLoader.loadAdjacentReaderSession(
                from: chapter.sourceURL,
                context: AdjacentReaderSessionLoadContext(currentSession: originalSession, direction: direction)
            )
            guard !loadedSession.imageURLs.isEmpty else {
                throw URLError(.cannotDecodeContentData)
            }
            loadedSession = preparedAdjacentSession(loadedSession, preserving: originalSession)
            await replaceSession(loadedSession)
            adjacentLoadState = .idle
        } catch {
            session = originalSession
            adjacentLoadState = .failed(direction, message: direction.failureMessage)
            isChromeVisible = true
        }
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
                    chapterLabel: chapterLabel(from: session.chapterTitle),
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
                        chapterLabel: chapterLabel(from: session.chapterTitle),
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
            guard let result = try await cacheMetadataManager?.recordCacheMetadata(
                CacheMetadataInput(
                    sourceURL: session.sourceURL,
                    seriesTitle: session.seriesTitle,
                    chapterTitle: session.chapterTitle,
                    chapterLabel: chapterLabel(from: session.chapterTitle),
                    imageCount: session.imageURLs.count,
                    estimatedStorageBytes: 0,
                    retentionState: .retained
                )
            ) else {
                return
            }
            cacheFeedback = .success(result)
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

    public func saveCurrentSessionToLibrary() async {
        guard let libraryLifecycleService else { return }
        do {
            await enrichSessionMetadataIfNeeded()
            try await libraryLifecycleService.addToLibrary(session.libraryInput, context: .reader)
            isSavedToLibrary = true
            libraryFeedback = CacheActionFeedback(result: nil, message: "Saved to Library.", isFailure: false)
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
    }

    public func setPageSpacingEnabled(_ isEnabled: Bool) {
        settings.isPageSpacingEnabled = isEnabled
        session.settings = settings
    }

    public func setBrightnessAid(_ value: Double) {
        settings.brightnessAid = min(0.75, max(0, value))
        session.settings = settings
    }

    public func setCanvas(_ canvas: ReaderCanvas) {
        settings.readerCanvas = canvas
        session.settings = settings
    }

    private func chapterLabel(from title: String) -> String {
        title
            .split(separator: " ")
            .last
            .map(String.init) ?? title
    }

    private func conciseChapterLabel(from title: String) -> String {
        let tokens = title
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        for index in tokens.indices {
            guard tokens[index].localizedCaseInsensitiveCompare("chapter") == .orderedSame else {
                continue
            }

            let nextIndex = tokens.index(after: index)
            guard tokens.indices.contains(nextIndex) else {
                return "Chapter"
            }

            let rawLabel = tokens[nextIndex].trimmingCharacters(in: .punctuationCharacters)
            guard !rawLabel.isEmpty else {
                return "Chapter"
            }
            return "Chapter \(rawLabel)"
        }

        return title
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
        LibrarySeriesInput(
            id: seriesID,
            title: seriesTitle,
            canonicalURL: seriesURL,
            sourceDomain: sourceDomain,
            coverImageURL: coverImageURL,
            status: seriesStatus,
            synopsis: seriesSynopsis,
            latestKnownChapterLabel: chapterTitle.split(separator: " ").last.map(String.init),
            libraryState: .reading,
            chapters: [
                LibraryChapterInput(
                    title: chapterTitle,
                    chapterLabel: chapterTitle.split(separator: " ").last.map(String.init) ?? chapterTitle,
                    chapterNumber: Double(chapterTitle.split(separator: " ").last.map(String.init) ?? ""),
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
