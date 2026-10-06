import Foundation
import SwiftData

@MainActor
public final class SwiftDataLibraryRepository: LibraryLifecycleManaging, LibraryChapterIndexManaging, ReaderProgressStoring, SearchHistoryManaging, RecentReadingRecording, CacheMetadataManaging {
    private let modelContext: ModelContext
    private let modelContainer: ModelContainer?
    private let usesModelContextIO: Bool
    private let historySave: (ModelContext) throws -> Void
    private var seriesStore: [UUID: StoredSeries] = [:]
    private var chapterStore: [UUID: StoredChapter] = [:]
    private var progressStore: [String: StoredProgress] = [:]
    private var searchHistoryStore: [String: StoredSearchHistory] = [:]
    private var recentReadingStore: [UUID: StoredRecentReading] = [:]
    private var cacheEntryStore: [String: StoredCacheEntry] = [:]
    private var hasNormalizedDuplicateRecordsThisSession = false

    public init(
        modelContext: ModelContext,
        modelContainer: ModelContainer? = nil,
        usesModelContextIO: Bool = true,
        historySave: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.modelContext = modelContext
        self.modelContainer = modelContainer
        self.usesModelContextIO = usesModelContextIO
        self.historySave = historySave
    }

    public func homeSnapshot() async -> HomeSnapshot {
        let library = await librarySnapshot()
        return HomeSnapshot(
            continueReading: HomeContinueReadingBuilder.summaries(from: library),
            recentlyUpdated: library.series.filter(\.hasUnreadUpdates).map(homeSummary),
            library: library.series.map(homeSummary)
        )
    }

    public func librarySnapshot() async -> LibrarySnapshot {
        normalizeDuplicateRecordsIfNeeded()
        reconcileRecentReadingsWithSavedSeriesIfNeeded()
        let allSeries = fetchSeries()
        let series = allSeries.filter { !isDomainPlaceholder(title: $0.title, sourceDomain: $0.sourceDomain) }
        return LibrarySnapshot(
            series: series.map(seriesSummary),
            recentReadSeries: fetchRecentReadings().compactMap { recentReadingSummary($0, replacingPlaceholderWith: series) }
        )
    }

    public func librarySearchItems() async -> [LibrarySearchItem] {
        fetchSeries()
            .filter { !isDomainPlaceholder(title: $0.title, sourceDomain: $0.sourceDomain) }
            .map { series in
                let currentChapter = series.lastOpenedChapterID.flatMap(fetchChapter(id:))
                return LibrarySearchItem(
                    id: series.id,
                    title: series.title,
                    sourceDomain: series.sourceDomain,
                    libraryState: libraryState(for: series),
                    currentChapterLabel: currentChapter.map(summaryChapterLabel),
                    coverImageURL: series.coverImageURLString.flatMap(URL.init(string:))
                )
            }
    }

    public func seriesDetail(for seriesID: UUID) async -> SeriesDetailSnapshot? {
        reconcileRecentReadingsWithSavedSeriesIfNeeded()
        if let series = fetchSeries(id: seriesID) {
            guard !isDomainPlaceholder(title: series.title, sourceDomain: series.sourceDomain) else {
                return nil
            }
            let chapters = fetchChapters(seriesID: seriesID)
            return SeriesDetailSnapshot(
                id: series.id,
                title: series.title,
                status: series.status,
                synopsis: series.synopsis,
                sourceDomain: series.sourceDomain,
                coverImageURL: series.coverImageURLString.flatMap(URL.init(string:)),
                isSaved: true,
                libraryState: libraryState(for: series),
                progressPercent: progressPercent(for: series, chapters: chapters),
                chaptersRead: chaptersRead(for: chapters),
                totalKnownChapters: chapters.count,
                hasUnreadUpdates: series.hasUnreadUpdates,
                chapters: chapters.map(chapterSummary)
            )
        }

        guard let recent = fetchRecentReading(seriesID: seriesID),
              !isDomainPlaceholder(title: recent.seriesTitle, sourceDomain: recent.sourceDomain),
              let sourceURL = URL(string: recent.sourceURLString) else {
            return nil
        }

        return SeriesDetailSnapshot(
            id: recent.seriesID,
            title: recent.seriesTitle,
            status: "Recent",
            synopsis: "Recently read in ToonEdge.",
            sourceDomain: recent.sourceDomain,
            coverImageURL: recent.coverImageURLString.flatMap(URL.init(string:)),
            isSaved: false,
            libraryState: .reading,
            progressPercent: ReaderProgress(
                currentImageIndex: recent.currentImageIndex,
                totalImageCount: recent.totalImageCount
            ).fractionComplete,
            chaptersRead: 0,
            totalKnownChapters: 1,
            hasUnreadUpdates: false,
            chapters: [
                ChapterSummary(
                    id: recent.chapterID,
                    title: recent.chapterTitle,
                    chapterLabel: recent.chapterLabel,
                    chapterNumber: Double(recent.chapterLabel),
                    sourceURL: sourceURL,
                    readState: .inProgress(
                        progressPercent: ReaderProgress(
                            currentImageIndex: recent.currentImageIndex,
                            totalImageCount: recent.totalImageCount
                        ).fractionComplete
                    ),
                    isDownloaded: false,
                    publishedAt: nil,
                    lastReadAt: recent.lastReadAt
                )
            ]
        )
    }

    public func addToLibrary(_ input: LibrarySeriesInput, context: LibraryAddContext) async throws {
        markDuplicateNormalizationStale()
        let now = Date()
        let defaultState = input.libraryState ?? defaultLibraryState(for: context)
        let canonicalURL = CanonicalSeriesURLResolver.seriesURL(for: input.canonicalURL)

        let resolvedSeriesID = fetchSeries(canonicalURLString: canonicalURL.absoluteString)?.id ?? input.id

        if let existing = fetchSeries(id: resolvedSeriesID) ?? fetchSeries(canonicalURLString: canonicalURL.absoluteString) {
            existing.title = input.title
            existing.canonicalURLString = canonicalURL.absoluteString
            existing.sourceDomain = input.sourceDomain
            if let coverImageURL = input.coverImageURL {
                existing.coverImageURLString = coverImageURL.absoluteString
            }
            existing.status = input.status
            existing.synopsis = input.synopsis
            existing.latestKnownChapterLabel = input.latestKnownChapterLabel
            existing.libraryStateRaw = defaultState.rawValue
            existing.isCompleted = defaultState == .completed
            existing.updatedAt = now
        } else {
            let series = StoredSeries(
                id: resolvedSeriesID,
                title: input.title,
                canonicalURLString: canonicalURL.absoluteString,
                sourceDomain: input.sourceDomain,
                coverImageURLString: input.coverImageURL?.absoluteString,
                status: input.status,
                synopsis: input.synopsis,
                latestKnownChapterLabel: input.latestKnownChapterLabel,
                hasUnreadUpdates: false,
                libraryStateRaw: defaultState.rawValue,
                isCompleted: defaultState == .completed,
                lastOpenedChapterID: nil,
                lastReadAt: nil,
                createdAt: now,
                updatedAt: now
            )
            seriesStore[resolvedSeriesID] = series
            insert(series)
        }

        for chapter in input.chapters {
            upsertChapter(chapter, seriesID: resolvedSeriesID, updatedAt: now)
        }

        try saveContextIfNeeded()
    }

    public func removeFromLibrary(seriesID: UUID) async throws {
        markDuplicateNormalizationStale()
        if fetchSeries(id: seriesID) != nil {
            fetchSeries(id: seriesID).map(delete)
            seriesStore.removeValue(forKey: seriesID)
        }

        for chapter in fetchChapters(seriesID: seriesID) {
            if fetchProgress(sourceURLString: chapter.sourceURLString) != nil {
                fetchProgress(sourceURLString: chapter.sourceURLString).map(delete)
                progressStore.removeValue(forKey: chapter.sourceURLString)
            }
            delete(chapter)
            chapterStore.removeValue(forKey: chapter.id)
        }

        try saveContextIfNeeded()
    }

    public func updateLibraryState(_ state: LibraryCollectionState, for seriesID: UUID) async throws {
        guard let series = fetchSeries(id: seriesID) else {
            return
        }

        series.libraryStateRaw = state.rawValue
        series.isCompleted = state == .completed
        series.updatedAt = Date()
        try saveContextIfNeeded()
    }

    public func recordUpdateCheckResult(
        seriesID: UUID,
        latestChapterLabel: String?,
        hasUnreadUpdates: Bool,
        checkedAt: Date
    ) async throws {
        guard let series = fetchSeries(id: seriesID) else {
            return
        }

        series.latestKnownChapterLabel = latestChapterLabel
        series.hasUnreadUpdates = hasUnreadUpdates
        series.updatedAt = checkedAt
        try saveContextIfNeeded()
    }

    public func recordAvailableChapters(
        _ chapters: [ChapterIndexEntry],
        for seriesID: UUID,
        indexedAt: Date
    ) async throws {
        markDuplicateNormalizationStale()
        guard let series = fetchSeries(id: seriesID) else {
            return
        }

        for chapter in chapters {
            upsertIndexedChapter(chapter, seriesID: seriesID, indexedAt: indexedAt)
        }

        if let latestLabel = chapters.max(by: { ($0.chapterNumber ?? -1) < ($1.chapterNumber ?? -1) })?.chapterLabel {
            series.latestKnownChapterLabel = latestLabel
        }
        series.updatedAt = indexedAt
        try saveContextIfNeeded()
    }

    public func recordReadingProgress(_ progress: ReaderProgress, forChapterID chapterID: UUID, at date: Date) async throws {
        guard let chapter = fetchChapter(id: chapterID),
              let series = fetchSeries(id: chapter.seriesID) else {
            return
        }

        upsertProgress(progress, chapterID: chapterID, sourceURLString: chapter.sourceURLString, updatedAt: date)
        series.lastOpenedChapterID = chapterID
        series.lastReadAt = date
        if libraryState(for: series) == .planned {
            series.libraryStateRaw = LibraryCollectionState.reading.rawValue
        }
        if progress.fractionComplete >= 1, fetchChapters(seriesID: series.id).allSatisfy({ chapterSummary($0).readState == .read || $0.id == chapterID }) {
            series.libraryStateRaw = LibraryCollectionState.completed.rawValue
            series.isCompleted = true
        }
        series.updatedAt = date
        try saveContextIfNeeded()
    }

    public func continueReadingTarget(for seriesID: UUID) async -> ContinueReadingTarget? {
        guard let series = fetchSeries(id: seriesID),
              let chapterID = series.lastOpenedChapterID,
              let chapter = fetchChapter(id: chapterID),
              let sourceURL = URL(string: chapter.sourceURLString),
              let progress = fetchProgress(sourceURLString: chapter.sourceURLString) else {
            return nil
        }

        return ContinueReadingTarget(
            seriesID: seriesID,
            chapterID: chapterID,
            sourceURL: sourceURL,
            progress: ReaderProgress(currentImageIndex: progress.currentImageIndex, totalImageCount: progress.totalImageCount)
        )
    }

    public func readerSession(forChapterID chapterID: UUID) async -> MockReaderSession? {
        guard let chapter = fetchChapter(id: chapterID),
              let series = fetchSeries(id: chapter.seriesID),
              let sourceURL = URL(string: chapter.sourceURLString),
              let seriesURL = URL(string: series.canonicalURLString) else {
            return nil
        }

        let imageURLs = decodedURLStrings(chapter.imageURLStrings).compactMap(URL.init(string:))
        guard !imageURLs.isEmpty else {
            return nil
        }
        let derivedAdjacent = adjacentChapters(for: chapter, in: series.id)

        return MockReaderSession(
            seriesID: series.id,
            seriesTitle: series.title,
            seriesURL: seriesURL,
            sourceDomain: series.sourceDomain,
            coverImageURL: series.coverImageURLString.flatMap(URL.init(string:)),
            seriesStatus: series.status,
            seriesSynopsis: series.synopsis,
            chapterTitle: chapter.title,
            sourceURL: sourceURL,
            imageURLs: imageURLs,
            previousChapter: derivedAdjacent.previous,
            nextChapter: derivedAdjacent.next
        )
    }

    public func readerSession(forSourceURL sourceURL: URL) async -> MockReaderSession? {
        guard let chapter = fetchChapter(sourceURLString: sourceURL.absoluteString) else {
            return nil
        }

        return await readerSession(forChapterID: chapter.id)
    }

    public func isSaved(canonicalURL: URL) async -> Bool {
        fetchSeries(canonicalURLString: canonicalURL.absoluteString) != nil
    }

    public func progress(for sourceURL: URL) async -> ReaderProgress? {
        guard let stored = fetchProgress(sourceURLString: sourceURL.absoluteString) else {
            return nil
        }

        return ReaderProgress(currentImageIndex: stored.currentImageIndex, totalImageCount: stored.totalImageCount)
    }

    public func save(_ progress: ReaderProgress, for sourceURL: URL) async {
        let now = Date()
        let knownChapter = fetchChapter(sourceURLString: sourceURL.absoluteString)
        upsertProgress(progress, chapterID: knownChapter?.id, sourceURLString: sourceURL.absoluteString, updatedAt: now)

        if let knownChapter, let series = fetchSeries(id: knownChapter.seriesID) {
            series.lastOpenedChapterID = knownChapter.id
            series.lastReadAt = now
            if libraryState(for: series) == .planned {
                series.libraryStateRaw = LibraryCollectionState.reading.rawValue
            }
            series.updatedAt = now
        }

        try? saveContextIfNeeded()
    }

    public func recordSearchHistory(_ input: SearchHistoryInput) async throws {
        let context = makeHistoryContext()
        let entries = try fetchSearchHistory(in: context)
        if let existing = entries.first(where: { $0.value == input.value }) {
            guard existing.kindRaw != input.kind.rawValue || existing.displayTitle != input.displayTitle || existing.lastUsedAt != input.createdAt else { return }
            existing.kindRaw = input.kind.rawValue
            existing.displayTitle = input.displayTitle
            existing.lastUsedAt = input.createdAt
        } else {
            let entry = StoredSearchHistory(
                id: UUID(), kindRaw: input.kind.rawValue, value: input.value,
                displayTitle: input.displayTitle, createdAt: input.createdAt, lastUsedAt: input.createdAt
            )
            if let context {
                context.insert(entry)
            } else {
                searchHistoryStore[input.value] = entry
            }
        }
        try saveHistory(context)
    }

    public func recentSearchHistory(limit: Int) async throws -> [SearchHistoryEntry] {
        guard limit > 0 else { return [] }
        return Array(try fetchSearchHistory(in: makeHistoryContext()).prefix(limit)).map { stored in
            SearchHistoryEntry(
                id: stored.id,
                kind: SearchHistoryKind(rawValue: stored.kindRaw) ?? .searchQuery,
                value: stored.value, displayTitle: stored.displayTitle, lastUsedAt: stored.lastUsedAt
            )
        }
    }

    public func removeSearchHistory(id: UUID) async throws {
        let context = makeHistoryContext()
        guard let entry = try fetchSearchHistory(in: context).first(where: { $0.id == id }) else { return }
        if let context {
            context.delete(entry)
        } else {
            searchHistoryStore.removeValue(forKey: entry.value)
        }
        try saveHistory(context)
    }

    public func clearSearchHistory() async throws {
        let context = makeHistoryContext()
        let entries = try fetchSearchHistory(in: context)
        guard !entries.isEmpty else { return }
        if let context {
            for entry in entries { context.delete(entry) }
        } else {
            searchHistoryStore.removeAll()
        }
        try saveHistory(context)
    }

    public func recordRecentReading(_ input: RecentReadingInput) async throws {
        markDuplicateNormalizationStale()
        let canonicalChapterLabel = ChapterNumericLabelExtractor.canonicalLabel(
            chapterNumber: nil,
            chapterLabel: input.chapterLabel,
            title: input.chapterTitle,
            sourceURL: input.sourceURL
        )
        if let existing = fetchRecentReading(seriesURLString: input.seriesURL.absoluteString) ?? fetchRecentReading(seriesID: input.seriesID) {
            existing.chapterID = input.chapterID
            existing.seriesTitle = input.seriesTitle
            existing.seriesURLString = input.seriesURL.absoluteString
            existing.sourceDomain = input.sourceDomain
            if let coverImageURL = input.coverImageURL {
                existing.coverImageURLString = coverImageURL.absoluteString
            }
            existing.chapterTitle = input.chapterTitle
            existing.chapterLabel = canonicalChapterLabel
            existing.sourceURLString = input.sourceURL.absoluteString
            existing.imageURLStrings = encodeURLStrings(input.imageURLs)
            existing.currentImageIndex = input.progress.currentImageIndex
            existing.totalImageCount = input.progress.totalImageCount
            existing.lastReadAt = input.readAt
            existing.updatedAt = input.readAt
        } else {
            let entry = StoredRecentReading(
                seriesID: input.seriesID,
                chapterID: input.chapterID,
                seriesTitle: input.seriesTitle,
                seriesURLString: input.seriesURL.absoluteString,
                sourceDomain: input.sourceDomain,
                coverImageURLString: input.coverImageURL?.absoluteString,
                chapterTitle: input.chapterTitle,
                chapterLabel: canonicalChapterLabel,
                sourceURLString: input.sourceURL.absoluteString,
                imageURLStrings: encodeURLStrings(input.imageURLs),
                currentImageIndex: input.progress.currentImageIndex,
                totalImageCount: input.progress.totalImageCount,
                lastReadAt: input.readAt,
                updatedAt: input.readAt
            )
            recentReadingStore[input.seriesID] = entry
            insert(entry)
        }

        reconcileSavedSeriesProgress(with: input)
        try saveContextIfNeeded()
    }

    public func recordCacheMetadata(_ input: CacheMetadataInput) async throws -> CacheActionResult {
        let existing = fetchCacheEntry(sourceURLString: input.sourceURL.absoluteString)
        let result = cacheActionResult(
            previous: existing.map(cacheRetentionState(for:)),
            next: input.retentionState
        )
        upsertCacheEntry(input, updatedAt: input.cachedAt)
        syncChapterCacheMetadata(
            sourceURLString: input.sourceURL.absoluteString,
            retentionState: input.retentionState,
            cachedAt: input.cachedAt
        )
        try saveContextIfNeeded()
        return result
    }

    private func reconcileSavedSeriesProgress(with input: RecentReadingInput) {
        let existingChapter = fetchChapter(sourceURLString: input.sourceURL.absoluteString) ?? fetchChapter(id: input.chapterID)
        guard let series = existingChapter.flatMap({ fetchSeries(id: $0.seriesID) }) ?? savedSeries(matching: input),
              !isDomainPlaceholder(title: series.title, sourceDomain: series.sourceDomain) else {
            return
        }
        let chapter = existingChapter ?? insertRecentChapter(input, seriesID: series.id)

        upsertProgress(
            input.progress,
            chapterID: chapter.id,
            sourceURLString: chapter.sourceURLString,
            updatedAt: input.readAt
        )
        series.lastOpenedChapterID = chapter.id
        series.lastReadAt = input.readAt
        if libraryState(for: series) == .planned {
            series.libraryStateRaw = LibraryCollectionState.reading.rawValue
        }
        series.updatedAt = input.readAt
    }

    private func reconcileRecentReadingsWithSavedSeriesIfNeeded() {
        for recent in fetchRecentReadings() {
            guard let sourceURL = URL(string: recent.sourceURLString),
                  let seriesURL = URL(string: recent.seriesURLString) else {
                continue
            }

            reconcileSavedSeriesProgress(
                with: RecentReadingInput(
                    seriesID: recent.seriesID,
                    chapterID: recent.chapterID,
                    seriesTitle: recent.seriesTitle,
                    seriesURL: seriesURL,
                    sourceDomain: recent.sourceDomain,
                    coverImageURL: recent.coverImageURLString.flatMap(URL.init(string:)),
                    chapterTitle: recent.chapterTitle,
                    chapterLabel: recent.chapterLabel,
                    sourceURL: sourceURL,
                    imageURLs: decodedURLStrings(recent.imageURLStrings).compactMap(URL.init(string:)),
                    progress: ReaderProgress(
                        currentImageIndex: recent.currentImageIndex,
                        totalImageCount: recent.totalImageCount
                    ),
                    readAt: recent.lastReadAt
                )
            )
        }

        try? saveContextIfNeeded()
    }

    private func savedSeries(matching input: RecentReadingInput) -> StoredSeries? {
        if let series = fetchSeries(id: input.seriesID) {
            return series
        }

        let canonicalURL = CanonicalSeriesURLResolver.seriesURL(for: input.seriesURL)
        return fetchSeries(canonicalURLString: canonicalURL.absoluteString)
    }

    private func insertRecentChapter(_ input: RecentReadingInput, seriesID: UUID) -> StoredChapter {
        let numericLabel = ChapterNumericLabelExtractor.label(
            chapterNumber: Double(input.chapterLabel),
            chapterLabel: input.chapterLabel,
            title: input.chapterTitle
        )
        let chapter = StoredChapter(
            id: input.chapterID,
            seriesID: seriesID,
            title: input.chapterTitle,
            chapterLabel: numericLabel ?? input.chapterLabel,
            chapterNumber: numericLabel.flatMap(Double.init),
            sourceURLString: input.sourceURL.absoluteString,
            previousChapterURLString: nil,
            nextChapterURLString: nil,
            imageURLStrings: encodeURLStrings(input.imageURLs),
            isDownloaded: false,
            publishedAt: nil,
            cachedAt: nil,
            updatedAt: input.readAt
        )
        chapterStore[input.chapterID] = chapter
        insert(chapter)
        return chapter
    }

    public func removeCacheMetadata(for sourceURL: URL) async throws -> CacheActionResult {
        let sourceURLString = sourceURL.absoluteString
        let didRemove = fetchCacheEntry(sourceURLString: sourceURLString) != nil
        if let existing = fetchCacheEntry(sourceURLString: sourceURLString) {
            delete(existing)
            cacheEntryStore.removeValue(forKey: sourceURLString)
        }

        if let chapter = fetchChapter(sourceURLString: sourceURLString) {
            chapter.cachedAt = nil
            chapter.isDownloaded = false
            chapter.updatedAt = Date()
        }

        try saveContextIfNeeded()
        return didRemove ? .removed : .notFound
    }

    public func updateCacheRetention(
        for sourceURL: URL,
        retentionState: CacheRetentionState,
        cachedAt: Date
    ) async throws -> CacheActionResult {
        let sourceURLString = sourceURL.absoluteString
        let previousRetention = fetchCacheEntry(sourceURLString: sourceURLString).map(cacheRetentionState(for:))
        let result = cacheActionResult(previous: previousRetention, next: retentionState)
        if let existing = fetchCacheEntry(sourceURLString: sourceURLString) {
            existing.retentionStateRaw = retentionState.rawValue
            existing.cachedAt = cachedAt
            existing.updatedAt = cachedAt
        } else {
            let chapter = fetchChapter(sourceURLString: sourceURLString)
            let input = CacheMetadataInput(
                sourceURL: sourceURL,
                seriesTitle: chapter.flatMap { fetchSeries(id: $0.seriesID)?.title } ?? "Unknown Series",
                chapterTitle: chapter?.title ?? "Unknown Chapter",
                chapterLabel: chapter?.chapterLabel,
                imageCount: chapter.map { decodedURLStrings($0.imageURLStrings).count } ?? 0,
                estimatedStorageBytes: 0,
                retentionState: retentionState,
                cachedAt: cachedAt
            )
            upsertCacheEntry(input, updatedAt: cachedAt)
        }

        syncChapterCacheMetadata(
            sourceURLString: sourceURLString,
            retentionState: retentionState,
            cachedAt: cachedAt
        )
        try saveContextIfNeeded()
        return result
    }

    public func cacheMetadataEntries() async -> [CacheMetadataEntry] {
        fetchCacheEntries().map(cacheMetadataEntry)
    }

    public func downloadSummary() async -> DownloadSummary {
        let entries = fetchCacheEntries()
        let recentCount = entries.filter { cacheRetentionState(for: $0) == .recent }.count
        let retainedCount = entries.filter { cacheRetentionState(for: $0) == .retained }.count
        let bytes = entries.map(\.estimatedStorageBytes).reduce(0, +)

        return DownloadSummary(
            cachedItemCount: entries.count,
            storageDescription: DownloadSummary.storageDescription(for: bytes),
            recentItemCount: recentCount,
            retainedItemCount: retainedCount,
            totalEstimatedBytes: bytes
        )
    }

    private func upsertChapter(_ input: LibraryChapterInput, seriesID: UUID, updatedAt: Date) {
        let canonicalChapterLabel = ChapterNumericLabelExtractor.canonicalLabel(
            chapterNumber: input.chapterNumber,
            chapterLabel: input.chapterLabel,
            title: input.title,
            sourceURL: input.sourceURL
        )
        if let existing = fetchChapter(sourceURLString: input.sourceURL.absoluteString) ?? fetchChapter(id: input.id) {
            existing.seriesID = seriesID
            existing.title = input.title
            existing.chapterLabel = canonicalChapterLabel
            existing.chapterNumber = input.chapterNumber
            existing.sourceURLString = input.sourceURL.absoluteString
            existing.previousChapterURLString = input.previousChapterURL?.absoluteString
            existing.nextChapterURLString = input.nextChapterURL?.absoluteString
            existing.imageURLStrings = encodeURLStrings(input.imageURLs)
            existing.publishedAt = input.publishedAt
            existing.updatedAt = updatedAt
        } else {
            let chapter = StoredChapter(
                id: input.id,
                seriesID: seriesID,
                title: input.title,
                chapterLabel: canonicalChapterLabel,
                chapterNumber: input.chapterNumber,
                sourceURLString: input.sourceURL.absoluteString,
                previousChapterURLString: input.previousChapterURL?.absoluteString,
                nextChapterURLString: input.nextChapterURL?.absoluteString,
                imageURLStrings: encodeURLStrings(input.imageURLs),
                isDownloaded: false,
                publishedAt: input.publishedAt,
                cachedAt: nil,
                updatedAt: updatedAt
            )
            chapterStore[input.id] = chapter
            insert(chapter)
        }
    }

    private func upsertIndexedChapter(_ input: ChapterIndexEntry, seriesID: UUID, indexedAt: Date) {
        let sourceURLString = input.sourceURL.absoluteString
        let canonicalChapterLabel = ChapterNumericLabelExtractor.canonicalLabel(
            chapterNumber: input.chapterNumber,
            chapterLabel: input.chapterLabel,
            title: input.title,
            sourceURL: input.sourceURL
        )
        if let existing = fetchChapter(sourceURLString: sourceURLString) ?? fetchChapter(id: input.id) {
            existing.seriesID = seriesID
            existing.title = input.title
            existing.chapterLabel = canonicalChapterLabel
            existing.chapterNumber = input.chapterNumber
            existing.sourceURLString = sourceURLString
            existing.publishedAt = input.publishedAt ?? existing.publishedAt
            existing.updatedAt = indexedAt
            return
        }

        let chapter = StoredChapter(
            id: input.id,
            seriesID: seriesID,
            title: input.title,
            chapterLabel: canonicalChapterLabel,
            chapterNumber: input.chapterNumber,
            sourceURLString: sourceURLString,
            previousChapterURLString: nil,
            nextChapterURLString: nil,
            imageURLStrings: encodeURLStrings([]),
            isDownloaded: false,
            publishedAt: input.publishedAt,
            cachedAt: nil,
            updatedAt: indexedAt
        )
        chapterStore[chapter.id] = chapter
        insert(chapter)
    }

    private func upsertProgress(_ progress: ReaderProgress, chapterID: UUID?, sourceURLString: String, updatedAt: Date) {
        if let existing = fetchProgress(sourceURLString: sourceURLString) {
            existing.chapterID = chapterID ?? existing.chapterID
            existing.currentImageIndex = progress.currentImageIndex
            existing.totalImageCount = progress.totalImageCount
            existing.updatedAt = updatedAt
        } else {
            let stored = StoredProgress(
                id: UUID(),
                chapterID: chapterID,
                sourceURLString: sourceURLString,
                currentImageIndex: progress.currentImageIndex,
                totalImageCount: progress.totalImageCount,
                lastReadOffset: nil,
                updatedAt: updatedAt
            )
            progressStore[sourceURLString] = stored
            insert(stored)
        }
    }

    private func upsertCacheEntry(_ input: CacheMetadataInput, updatedAt: Date) {
        let sourceURLString = input.sourceURL.absoluteString
        let canonicalChapterLabel = input.chapterLabel.map { ChapterNumericLabelExtractor.canonicalLabel(
            chapterNumber: nil,
            chapterLabel: $0,
            title: input.chapterTitle,
            sourceURL: input.sourceURL
        ) }
        if let existing = fetchCacheEntry(sourceURLString: sourceURLString) {
            existing.seriesTitle = input.seriesTitle
            existing.chapterTitle = input.chapterTitle
            existing.chapterLabel = canonicalChapterLabel
            existing.imageCount = input.imageCount
            existing.estimatedStorageBytes = input.estimatedStorageBytes
            existing.retentionStateRaw = input.retentionState.rawValue
            existing.cachedAt = input.cachedAt
            existing.updatedAt = updatedAt
        } else {
            let entry = StoredCacheEntry(
                id: UUID(),
                sourceURLString: sourceURLString,
                seriesTitle: input.seriesTitle,
                chapterTitle: input.chapterTitle,
                chapterLabel: canonicalChapterLabel,
                imageCount: input.imageCount,
                estimatedStorageBytes: input.estimatedStorageBytes,
                retentionStateRaw: input.retentionState.rawValue,
                cachedAt: input.cachedAt,
                updatedAt: updatedAt
            )
            cacheEntryStore[sourceURLString] = entry
            insert(entry)
        }
    }

    private func syncChapterCacheMetadata(
        sourceURLString: String,
        retentionState: CacheRetentionState,
        cachedAt: Date
    ) {
        guard let chapter = fetchChapter(sourceURLString: sourceURLString) else {
            return
        }

        chapter.cachedAt = cachedAt
        chapter.isDownloaded = retentionState == .retained
        chapter.updatedAt = cachedAt
    }

    private func seriesSummary(_ series: StoredSeries) -> LibrarySeriesSummary {
        let chapters = fetchChapters(seriesID: series.id)
        let chapterSummaries = chapters.map(chapterSummary)
        let currentChapter = series.lastOpenedChapterID.flatMap(fetchChapter(id:))
        return LibrarySeriesSummary(
            id: series.id,
            title: series.title,
            sourceDomain: series.sourceDomain,
            canonicalURL: URL(string: series.canonicalURLString),
            coverImageURL: series.coverImageURLString.flatMap(URL.init(string:)),
            progressPercent: progressPercent(for: series, chapters: chapters),
            chaptersRead: chaptersRead(for: chapters),
            totalKnownChapters: chapters.count,
            lastReadAt: series.lastReadAt,
            libraryState: libraryState(for: series),
            hasUnreadUpdates: series.hasUnreadUpdates,
            isCompleted: series.isCompleted || libraryState(for: series) == .completed,
            latestChapterLabel: latestChapterLabel(for: series, chapters: chapters),
            currentChapterLabel: currentChapter.flatMap(summaryChapterLabel),
            resumeTarget: SeriesPrimaryChapterSelector.primaryChapter(in: chapterSummaries)
                .map(LibraryResumeTarget.init(chapter:))
        )
    }

    private func chapterSummary(_ chapter: StoredChapter) -> ChapterSummary {
        let progress = fetchProgress(sourceURLString: chapter.sourceURLString)
        return ChapterSummary(
            id: chapter.id,
            title: chapter.title,
            chapterLabel: chapter.chapterLabel,
            chapterNumber: chapter.chapterNumber,
            sourceURL: URL(string: chapter.sourceURLString) ?? URL(string: "about:blank")!,
            readState: readState(for: chapter),
            isDownloaded: chapter.isDownloaded,
            publishedAt: chapter.publishedAt,
            lastReadAt: progress?.updatedAt,
            isGeneratedPlaceholder: false,
            isOpenable: true
        )
    }

    private func cacheMetadataEntry(_ stored: StoredCacheEntry) -> CacheMetadataEntry {
        CacheMetadataEntry(
            id: stored.id,
            sourceURL: URL(string: stored.sourceURLString) ?? URL(string: "about:blank")!,
            seriesTitle: stored.seriesTitle,
            chapterTitle: stored.chapterTitle,
            chapterLabel: stored.chapterLabel,
            imageCount: stored.imageCount,
            estimatedStorageBytes: stored.estimatedStorageBytes,
            retentionState: cacheRetentionState(for: stored),
            cachedAt: stored.cachedAt
        )
    }

    private func recentReadingSummary(
        _ recent: StoredRecentReading,
        replacingPlaceholderWith realSeries: [StoredSeries] = []
    ) -> LibrarySeriesSummary? {
        if let replacement = matchingSeries(for: recent, in: realSeries) {
            var summary = seriesSummary(replacement)
            summary.lastReadAt = recent.lastReadAt
            summary.progressPercent = ReaderProgress(
                currentImageIndex: recent.currentImageIndex,
                totalImageCount: recent.totalImageCount
            ).fractionComplete
            summary.currentChapterLabel = summaryChapterLabel(for: recent)
            return summary
        }

        if isDomainPlaceholder(title: recent.seriesTitle, sourceDomain: recent.sourceDomain) {
            guard let replacement = realSeries.first(where: { $0.sourceDomain == recent.sourceDomain }) else {
                return nil
            }
            var summary = seriesSummary(replacement)
            summary.lastReadAt = recent.lastReadAt
            summary.progressPercent = ReaderProgress(
                currentImageIndex: recent.currentImageIndex,
                totalImageCount: recent.totalImageCount
            ).fractionComplete
            if summary.currentChapterLabel == nil {
                summary.currentChapterLabel = summaryChapterLabel(for: recent)
            }
            return summary
        }

        let recentChapter = ChapterSummary(
            id: recent.chapterID,
            title: recent.chapterTitle,
            chapterLabel: summaryChapterLabel(for: recent),
            chapterNumber: Double(summaryChapterLabel(for: recent)),
            sourceURL: URL(string: recent.sourceURLString) ?? URL(string: "about:blank")!,
            readState: .inProgress(
                progressPercent: ReaderProgress(
                    currentImageIndex: recent.currentImageIndex,
                    totalImageCount: recent.totalImageCount
                ).fractionComplete
            ),
            isDownloaded: false,
            publishedAt: nil,
            lastReadAt: recent.lastReadAt
        )

        return LibrarySeriesSummary(
            id: recent.seriesID,
            title: recent.seriesTitle,
            sourceDomain: recent.sourceDomain,
            canonicalURL: URL(string: recent.seriesURLString),
            coverImageURL: recent.coverImageURLString.flatMap(URL.init(string:)),
            progressPercent: ReaderProgress(
                currentImageIndex: recent.currentImageIndex,
                totalImageCount: recent.totalImageCount
            ).fractionComplete,
            chaptersRead: 0,
            totalKnownChapters: 1,
            lastReadAt: recent.lastReadAt,
            libraryState: .reading,
            hasUnreadUpdates: false,
            isCompleted: false,
            latestChapterLabel: summaryChapterLabel(for: recent),
            currentChapterLabel: summaryChapterLabel(for: recent),
            resumeTarget: LibraryResumeTarget(chapter: recentChapter)
        )
    }

    private func latestChapterLabel(for series: StoredSeries, chapters: [StoredChapter]) -> String? {
        series.latestKnownChapterLabel ?? chapters.max(by: chapterOrder).flatMap(summaryChapterLabel)
    }

    private func summaryChapterLabel(for chapter: StoredChapter) -> String {
        ChapterNumericLabelExtractor.label(
            chapterNumber: chapter.chapterNumber,
            chapterLabel: chapter.chapterLabel,
            title: chapter.title
        ) ?? chapter.chapterLabel
    }

    private func summaryChapterLabel(for recent: StoredRecentReading) -> String {
        ChapterNumericLabelExtractor.canonicalLabel(
            chapterNumber: Double(recent.chapterLabel),
            chapterLabel: recent.chapterLabel,
            title: recent.chapterTitle,
            sourceURL: URL(string: recent.sourceURLString) ?? URL(string: "about:blank")!
        )
    }

    private func matchingSeries(for recent: StoredRecentReading, in realSeries: [StoredSeries]) -> StoredSeries? {
        let recentURL = URL(string: recent.seriesURLString)
        let recentCanonical = recentURL.map(LibraryIdentityNormalizer.normalizedCanonicalURL)
        let recentComparableTitle = comparableSeriesTitle(recent.seriesTitle)
        let recentDomain = LibraryIdentityNormalizer.normalizedSourceDomain(recent.sourceDomain)

        return realSeries.first { series in
            let seriesDomain = LibraryIdentityNormalizer.normalizedSourceDomain(series.sourceDomain)
            guard seriesDomain == recentDomain else {
                return false
            }

            if let recentCanonical,
               let seriesURL = URL(string: series.canonicalURLString) {
                let seriesCanonical = LibraryIdentityNormalizer.normalizedCanonicalURL(seriesURL)
                if recentCanonical == seriesCanonical
                    || recentCanonical.hasPrefix("\(seriesCanonical)/")
                    || seriesCanonical.hasPrefix("\(recentCanonical)/") {
                    return true
                }
            }

            return comparableSeriesTitle(series.title) == recentComparableTitle
        }
    }

    private func comparableSeriesTitle(_ title: String) -> String {
        let separators = ["|", " - ", " – ", " — "]
        let base = separators.reduce(title) { partial, separator in
            partial.components(separatedBy: separator).first ?? partial
        }
        return LibraryIdentityNormalizer.normalizedTitle(base)
    }

    private func readState(for chapter: StoredChapter) -> ChapterReadState {
        guard let progress = fetchProgress(sourceURLString: chapter.sourceURLString) else {
            return .unread
        }

        if progress.totalImageCount > 0 && ReaderProgress(
            currentImageIndex: progress.currentImageIndex,
            totalImageCount: progress.totalImageCount
        ).fractionComplete >= 1 {
            return .read
        }

        return .inProgress(
            progressPercent: ReaderProgress(
                currentImageIndex: progress.currentImageIndex,
                totalImageCount: progress.totalImageCount
            ).fractionComplete
        )
    }

    private func chaptersRead(for chapters: [StoredChapter]) -> Int {
        chapters.filter {
            if case .read = readState(for: $0) {
                return true
            }
            return false
        }.count
    }

    private func adjacentChapters(for chapter: StoredChapter, in seriesID: UUID) -> (previous: MockChapter?, next: MockChapter?) {
        let chapters = fetchChapters(seriesID: seriesID).sorted(by: chapterOrder)
        guard let currentNumber = integerChapterNumber(for: chapter) else {
            let storedAdjacent = adjacentChaptersByStoredOrder(for: chapter, in: chapters)
            return (
                previous: chapter.previousChapterURLString.flatMap(URL.init(string:)).map {
                    MockChapter(title: "Previous Chapter", sourceURL: $0)
                } ?? storedAdjacent.previous,
                next: chapter.nextChapterURLString.flatMap(URL.init(string:)).map {
                    MockChapter(title: "Next Chapter", sourceURL: $0)
                } ?? storedAdjacent.next
            )
        }

        var chaptersByNumber: [Int: StoredChapter] = [:]
        for storedChapter in chapters {
            guard let number = integerChapterNumber(for: storedChapter),
                  chaptersByNumber[number] == nil else {
                continue
            }
            chaptersByNumber[number] = storedChapter
        }

        return (
            previous: numericAdjacentChapter(
                targetNumber: currentNumber - 1,
                explicitURLString: chapter.previousChapterURLString,
                currentChapter: chapter,
                chaptersByNumber: chaptersByNumber
            ),
            next: numericAdjacentChapter(
                targetNumber: currentNumber + 1,
                explicitURLString: chapter.nextChapterURLString,
                currentChapter: chapter,
                chaptersByNumber: chaptersByNumber
            )
        )
    }

    private func adjacentChaptersByStoredOrder(
        for chapter: StoredChapter,
        in chapters: [StoredChapter]
    ) -> (previous: MockChapter?, next: MockChapter?) {
        guard let index = chapters.firstIndex(where: { $0.id == chapter.id }) else {
            return (nil, nil)
        }

        let previous = index > chapters.startIndex ? mockChapter(from: chapters[chapters.index(before: index)]) : nil
        let nextIndex = chapters.index(after: index)
        let next = nextIndex < chapters.endIndex ? mockChapter(from: chapters[nextIndex]) : nil
        return (previous, next)
    }

    private func numericAdjacentChapter(
        targetNumber: Int,
        explicitURLString: String?,
        currentChapter: StoredChapter,
        chaptersByNumber: [Int: StoredChapter]
    ) -> MockChapter? {
        guard targetNumber > 0 else {
            return nil
        }

        if let storedChapter = chaptersByNumber[targetNumber] {
            return mockChapter(from: storedChapter)
        }

        if let explicitURLString,
           let explicitURL = URL(string: explicitURLString),
           ChapterURLInference.containsChapterNumber(targetNumber, in: explicitURL) {
            return MockChapter(title: "Chapter \(targetNumber)", sourceURL: explicitURL)
        }

        guard let currentNumber = integerChapterNumber(for: currentChapter),
              let currentSourceURL = URL(string: currentChapter.sourceURLString),
              let inferredURL = ChapterURLInference.inferredSourceURL(
                forChapter: targetNumber,
                knownChapters: [
                    ChapterURLInference.KnownChapter(
                        number: currentNumber,
                        sourceURL: currentSourceURL
                    )
                ]
              ) else {
            return nil
        }

        return MockChapter(
            title: "Chapter \(targetNumber)",
            sourceURL: inferredURL
        )
    }

    private func mockChapter(from chapter: StoredChapter) -> MockChapter? {
        guard let sourceURL = URL(string: chapter.sourceURLString) else {
            return nil
        }

        return MockChapter(
            id: chapter.id,
            title: chapter.title,
            sourceURL: sourceURL
        )
    }

    private func integerChapterNumber(for chapter: StoredChapter) -> Int? {
        ChapterURLInference.integerChapterNumber(
            chapterNumber: chapter.chapterNumber,
            chapterLabel: chapter.chapterLabel,
            title: chapter.title
        )
    }

    private func progressPercent(for series: StoredSeries, chapters: [StoredChapter]) -> Double {
        guard !chapters.isEmpty else {
            return 0
        }

        if series.isCompleted || libraryState(for: series) == .completed {
            return 1
        }

        let read = Double(chaptersRead(for: chapters))
        let partial = chapters
            .map { chapter -> Double in
                if case .inProgress(let progressPercent) = readState(for: chapter) {
                    return progressPercent
                }
                return 0
            }
            .reduce(0, +)

        return min(1, max(0, (read + partial) / Double(chapters.count)))
    }

    private func homeSummary(_ series: LibrarySeriesSummary) -> SeriesSummary {
        let subtitle: String
        if series.hasUnreadUpdates, let latestChapterLabel = series.latestChapterLabel {
            subtitle = "New Chapter \(latestChapterLabel)"
        } else if let currentChapterLabel = series.currentChapterLabel {
            subtitle = "Continue Chapter \(currentChapterLabel)"
        } else {
            subtitle = series.libraryState.title
        }

        return SeriesSummary(
            id: series.id,
            title: series.title,
            subtitle: subtitle,
            coverImageURL: series.coverImageURL,
            progressPercent: series.progressPercent,
            hasUnreadUpdates: series.hasUnreadUpdates
        )
    }

    private func isDomainPlaceholder(title: String, sourceDomain: String) -> Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == sourceDomain.lowercased()
    }

    private func defaultLibraryState(for context: LibraryAddContext) -> LibraryCollectionState {
        AddToLibraryStatePickerModel.defaultState(for: context)
    }

    private func libraryState(for series: StoredSeries) -> LibraryCollectionState {
        LibraryCollectionState.decoded(persistedRawValue: series.libraryStateRaw)
    }

    private func encodeURLStrings(_ urls: [URL]) -> String {
        urls.map(\.absoluteString).joined(separator: "\n")
    }

    private func decodedURLStrings(_ value: String) -> [String] {
        value
            .split(separator: "\n")
            .map(String.init)
    }

    private func chapterOrder(_ lhs: StoredChapter, _ rhs: StoredChapter) -> Bool {
        let lhsNumber = lhs.chapterNumber ?? .leastNonzeroMagnitude
        let rhsNumber = rhs.chapterNumber ?? .leastNonzeroMagnitude
        if lhsNumber == rhsNumber {
            return lhs.chapterLabel < rhs.chapterLabel
        }
        return lhsNumber < rhsNumber
    }

    private func fetchSeries() -> [StoredSeries] {
        if usesModelContextIO {
            return (try? modelContext.fetch(FetchDescriptor<StoredSeries>()))?.sorted { lhs, rhs in
                lhs.updatedAt > rhs.updatedAt
            } ?? []
        }

        return seriesStore.values.sorted { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
        }
    }

    private func fetchSeries(id: UUID) -> StoredSeries? {
        if usesModelContextIO {
            var descriptor = FetchDescriptor<StoredSeries>(
                predicate: #Predicate { $0.id == id }
            )
            descriptor.fetchLimit = 1
            return try? modelContext.fetch(descriptor).first
        }

        return fetchSeries().first { $0.id == id }
    }

    private func fetchSeries(canonicalURLString: String) -> StoredSeries? {
        if usesModelContextIO {
            var descriptor = FetchDescriptor<StoredSeries>(
                predicate: #Predicate { $0.canonicalURLString == canonicalURLString }
            )
            descriptor.fetchLimit = 1
            if let exact = try? modelContext.fetch(descriptor).first {
                return exact
            }

            let normalized = normalizedCanonicalURLString(canonicalURLString)
            if normalized != canonicalURLString {
                var normalizedDescriptor = FetchDescriptor<StoredSeries>(
                    predicate: #Predicate { $0.canonicalURLString == normalized }
                )
                normalizedDescriptor.fetchLimit = 1
                if let exactNormalized = try? modelContext.fetch(normalizedDescriptor).first {
                    return exactNormalized
                }
            }
        }

        return fetchSeries().first {
            normalizedCanonicalURLString($0.canonicalURLString) == normalizedCanonicalURLString(canonicalURLString)
        }
    }

    private func fetchChapters(seriesID: UUID) -> [StoredChapter] {
        if usesModelContextIO {
            return (try? modelContext.fetch(FetchDescriptor<StoredChapter>(
                predicate: #Predicate { $0.seriesID == seriesID }
            )))?
                .sorted(by: chapterOrder) ?? []
        }

        return chapterStore.values
            .filter { $0.seriesID == seriesID }
            .sorted(by: chapterOrder)
    }

    private func fetchChapter(id: UUID) -> StoredChapter? {
        if usesModelContextIO {
            var descriptor = FetchDescriptor<StoredChapter>(
                predicate: #Predicate { $0.id == id }
            )
            descriptor.fetchLimit = 1
            return try? modelContext.fetch(descriptor).first
        }

        return chapterStore[id]
    }

    private func fetchChapter(sourceURLString: String) -> StoredChapter? {
        if usesModelContextIO {
            var descriptor = FetchDescriptor<StoredChapter>(
                predicate: #Predicate { $0.sourceURLString == sourceURLString }
            )
            descriptor.fetchLimit = 1
            return try? modelContext.fetch(descriptor).first
        }

        return chapterStore.values.first { $0.sourceURLString == sourceURLString }
    }

    private func fetchProgress(sourceURLString: String) -> StoredProgress? {
        if usesModelContextIO {
            var descriptor = FetchDescriptor<StoredProgress>(
                predicate: #Predicate { $0.sourceURLString == sourceURLString }
            )
            descriptor.fetchLimit = 1
            return try? modelContext.fetch(descriptor).first
        }

        return progressStore[sourceURLString]
    }

    /// A fresh history-only context also prevents cached models from hiding another
    /// history manager's committed changes. Library's pending edits stay isolated.
    private func makeHistoryContext() -> ModelContext? {
        guard usesModelContextIO else { return nil }
        let context = ModelContext(modelContainer ?? modelContext.container)
        context.autosaveEnabled = false
        return context
    }

    private func fetchSearchHistory(in context: ModelContext?) throws -> [StoredSearchHistory] {
        let entries: [StoredSearchHistory]
        if let context {
            entries = try context.fetch(FetchDescriptor<StoredSearchHistory>())
        } else {
            entries = Array(searchHistoryStore.values)
        }
        return entries.sorted { lhs, rhs in
            if lhs.lastUsedAt == rhs.lastUsedAt { return lhs.id.uuidString < rhs.id.uuidString }
            return lhs.lastUsedAt > rhs.lastUsedAt
        }
    }

    private func saveHistory(_ context: ModelContext?) throws {
        guard let context else { return }
        do {
            try historySave(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private func fetchRecentReading(seriesID: UUID) -> StoredRecentReading? {
        if usesModelContextIO {
            var descriptor = FetchDescriptor<StoredRecentReading>(
                predicate: #Predicate { $0.seriesID == seriesID }
            )
            descriptor.fetchLimit = 1
            return try? modelContext.fetch(descriptor).first
        }

        return fetchRecentReadings().first { $0.seriesID == seriesID }
    }

    private func fetchRecentReading(seriesURLString: String) -> StoredRecentReading? {
        if usesModelContextIO {
            var descriptor = FetchDescriptor<StoredRecentReading>(
                predicate: #Predicate { $0.seriesURLString == seriesURLString }
            )
            descriptor.fetchLimit = 1
            return try? modelContext.fetch(descriptor).first
        }

        return fetchRecentReadings().first { $0.seriesURLString == seriesURLString }
    }

    private func fetchRecentReadings() -> [StoredRecentReading] {
        if usesModelContextIO {
            return (try? modelContext.fetch(FetchDescriptor<StoredRecentReading>()))?.sorted { lhs, rhs in
                lhs.lastReadAt > rhs.lastReadAt
            } ?? []
        }

        return recentReadingStore.values.sorted { lhs, rhs in
            lhs.lastReadAt > rhs.lastReadAt
        }
    }

    private func normalizeDuplicateRecordsIfNeeded() {
        guard !hasNormalizedDuplicateRecordsThisSession else {
            return
        }
        defer {
            hasNormalizedDuplicateRecordsThisSession = true
        }

        for duplicates in Dictionary(grouping: fetchSeries(), by: { normalizedCanonicalURLString($0.canonicalURLString) }).values where duplicates.count > 1 {
            let ordered = duplicates.sorted { $0.updatedAt > $1.updatedAt }
            guard let keeper = ordered.first else { continue }
            keeper.canonicalURLString = normalizedCanonicalURLString(keeper.canonicalURLString)
            for duplicate in ordered.dropFirst() {
                for chapter in fetchChapters(seriesID: duplicate.id) {
                    chapter.seriesID = keeper.id
                    chapterStore[chapter.id] = chapter
                }
                delete(duplicate)
                seriesStore.removeValue(forKey: duplicate.id)
            }
        }

        for duplicates in Dictionary(grouping: fetchRecentReadings(), by: \.seriesURLString).values where duplicates.count > 1 {
            let ordered = duplicates.sorted { $0.lastReadAt > $1.lastReadAt }
            guard let keeper = ordered.first else { continue }
            for duplicate in ordered.dropFirst() {
                delete(duplicate)
                recentReadingStore.removeValue(forKey: duplicate.seriesID)
            }
            recentReadingStore[keeper.seriesID] = keeper
        }

        for duplicates in Dictionary(grouping: fetchAllChapters(), by: \.sourceURLString).values where duplicates.count > 1 {
            let ordered = duplicates.sorted { $0.updatedAt > $1.updatedAt }
            for duplicate in ordered.dropFirst() {
                delete(duplicate)
                chapterStore.removeValue(forKey: duplicate.id)
            }
        }

        try? saveContextIfNeeded()
    }

    private func markDuplicateNormalizationStale() {
        hasNormalizedDuplicateRecordsThisSession = false
    }

    private func normalizedCanonicalURLString(_ value: String) -> String {
        guard let url = URL(string: value) else {
            return value
        }

        return CanonicalSeriesURLResolver.seriesURL(for: url).absoluteString
    }

    private func fetchAllChapters() -> [StoredChapter] {
        if usesModelContextIO {
            return (try? modelContext.fetch(FetchDescriptor<StoredChapter>())) ?? []
        }
        return Array(chapterStore.values)
    }

    private func fetchCacheEntries() -> [StoredCacheEntry] {
        if usesModelContextIO {
            return (try? modelContext.fetch(FetchDescriptor<StoredCacheEntry>()))?.sorted { lhs, rhs in
                lhs.updatedAt > rhs.updatedAt
            } ?? []
        }

        return cacheEntryStore.values.sorted { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
        }
    }

    private func fetchCacheEntry(sourceURLString: String) -> StoredCacheEntry? {
        if usesModelContextIO {
            var descriptor = FetchDescriptor<StoredCacheEntry>(
                predicate: #Predicate { $0.sourceURLString == sourceURLString }
            )
            descriptor.fetchLimit = 1
            return try? modelContext.fetch(descriptor).first
        }

        return fetchCacheEntries().first { $0.sourceURLString == sourceURLString }
    }

    private func cacheRetentionState(for entry: StoredCacheEntry) -> CacheRetentionState {
        CacheRetentionState(rawValue: entry.retentionStateRaw) ?? .recent
    }

    private func cacheActionResult(
        previous: CacheRetentionState?,
        next: CacheRetentionState
    ) -> CacheActionResult {
        if previous == next {
            return .unchanged
        }

        switch next {
        case .recent:
            return .recent
        case .retained:
            return .retained
        }
    }

    private func saveContextIfNeeded() throws {
        if usesModelContextIO {
            try modelContext.save()
        }
    }

    private func insert<T: PersistentModel>(_ model: T) {
        guard usesModelContextIO else { return }
        modelContext.insert(model)
    }

    private func delete<T: PersistentModel>(_ model: T) {
        guard usesModelContextIO else { return }
        modelContext.delete(model)
    }
}
