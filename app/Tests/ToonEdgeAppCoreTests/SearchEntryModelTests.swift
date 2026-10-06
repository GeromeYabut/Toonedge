import Foundation
import SwiftData
import Testing
@testable import ToonEdgeAppCore

@Test @MainActor func savedSearchPresentationShowsLifecycleAndCurrentChapter() async throws {
    let item = LibrarySearchItem(id: UUID(), title: "Hero", sourceDomain: "example.com", libraryState: .reading, currentChapterLabel: "12", coverImageURL: nil)
    let model = SearchOverlayViewModel(libraryProvider: SearchOverlayLibrarySpy(items: [item]))
    await model.load()
    model.query = "hero"

    let suggestion = try #require(model.suggestions.first { $0.kind == .librarySeries })
    #expect(suggestion.subtitle == "example.com · Reading · Chapter 12")
    #expect(suggestion.destination == .librarySeries(item))
}

@Test @MainActor func savedSearchPresentationUsesEveryLocalLifecycleWithoutInventingProgress() async throws {
    for state in LibraryCollectionState.allCases {
        let item = LibrarySearchItem(id: UUID(), title: "Hero", sourceDomain: "example.com", libraryState: state, currentChapterLabel: nil, coverImageURL: nil)
        let model = SearchOverlayViewModel(libraryProvider: SearchOverlayLibrarySpy(items: [item]))
        await model.load()
        model.query = "hero"

        let suggestion = try #require(model.suggestions.first { $0.kind == .librarySeries })
        #expect(suggestion.subtitle == "example.com · \(state.title)")
    }
}

@Test @MainActor func savedSearchPresentationHandlesOptionalAndAlreadyNamedChapterLabels() async throws {
    let labels: [(String?, String)] = [
        (nil, "example.com · Reading"),
        ("  \n", "example.com · Reading"),
        (" 12 ", "example.com · Reading · Chapter 12"),
        ("Chapter 1", "example.com · Reading · Chapter 1"),
        ("chapter 2", "example.com · Reading · chapter 2"),
        ("Episode 3", "example.com · Reading · Episode 3"),
        ("Prologue", "example.com · Reading · Prologue")
    ]
    for (label, expected) in labels {
        let item = LibrarySearchItem(id: UUID(), title: "Hero", sourceDomain: "example.com", libraryState: .reading, currentChapterLabel: label, coverImageURL: nil)
        let model = SearchOverlayViewModel(libraryProvider: SearchOverlayLibrarySpy(items: [item]))
        await model.load()
        model.query = "hero"

        #expect(model.suggestions.first { $0.kind == .librarySeries }?.subtitle == expected)
    }
}

@Test @MainActor func savedSearchNativeRouteClearsExistingBrowserReaderAndConsumesSeriesOnce() async throws {
    let item = searchOverlayItem("Hero")
    let history = SearchOverlayHistorySpy(entries: [])
    let model = SearchOverlayViewModel(libraryProvider: SearchOverlayLibrarySpy(items: [item]), searchHistoryManager: history)
    await model.load()
    model.query = "hero"
    let suggestion = try #require(model.suggestions.first { $0.kind == .librarySeries })
    var router = AppRouter(
        activeSheet: .search,
        presentedBrowser: .url("https://example.com/old"),
        presentedReader: .sample,
        pendingLibrarySegment: .recent,
        presentedBrowserReaderLaunchOrigin: .homeContinueReading
    )

    #expect(model.select(suggestion, router: &router) == nil)
    #expect(router.activeSheet == nil)
    #expect(router.selectedTab == .library)
    #expect(router.presentedBrowser == nil)
    #expect(router.presentedReader == nil)
    #expect(router.presentedBrowserReaderLaunchOrigin == nil)
    #expect(router.pendingLibrarySegment == nil)
    #expect(router.consumePendingLibrarySeriesID() == item.id)
    #expect(router.consumePendingLibrarySeriesID() == nil)
    #expect(await history.recordedInputs.isEmpty)
}

@Test @MainActor func savedSearchNativeFlowUsesLocalRepositoryWithoutWebHistory() async throws {
    // No HTTP loader is supplied: both matching and detail resolve from local data.
    let schema = Schema(ToonEdgePersistenceModels.all)
    let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    let repository = SwiftDataLibraryRepository(modelContext: container.mainContext, modelContainer: container)
    let seriesID = UUID()
    try await repository.addToLibrary(LibrarySeriesInput(
        id: seriesID, title: "Offline Hero", canonicalURL: URL(string: "https://example.com/offline-hero")!,
        sourceDomain: "example.com", coverImageURL: nil, status: "Ongoing", synopsis: "Locally saved",
        latestKnownChapterLabel: nil, libraryState: .planned, chapters: []
    ), context: .seriesDetail)
    try await repository.recordSearchHistory(SearchHistoryInput(kind: .searchQuery, value: "earlier query", displayTitle: "Earlier query"))
    let originalHistory = try await repository.recentSearchHistory(limit: 12)
    let model = SearchOverlayViewModel(
        suggestionsProvider: MockSearchSuggestionProvider(clipboardURL: nil, recentLinks: [], recentSearches: [], commonSites: []),
        libraryProvider: repository, searchHistoryManager: repository
    )
    await model.load()
    model.query = "offline hero"
    let saved = try #require(model.suggestions.first { $0.kind == .librarySeries })
    var router = AppRouter(activeSheet: .search)
    #expect(model.select(saved, router: &router) == nil)
    let pendingSeriesID = router.consumePendingLibrarySeriesID()
    let routedID = try #require(pendingSeriesID)
    let detail = try #require(await repository.seriesDetail(for: routedID))
    #expect(detail.id == seriesID)
    #expect(detail.title == "Offline Hero")
    #expect(detail.libraryState == .planned)
    #expect(router.activeSheet == nil)
    #expect(router.selectedTab == .library)
    #expect(router.presentedBrowser == nil)
    #expect(try await repository.recentSearchHistory(limit: 12) == originalHistory)
}

@Test @MainActor func staleSavedSearchRouteKeepsNativeRecoveryWithoutWebFallback() async throws {
    let schema = Schema(ToonEdgePersistenceModels.all)
    let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    let repository = SwiftDataLibraryRepository(modelContext: container.mainContext, modelContainer: container)
    let seriesID = UUID()
    try await repository.addToLibrary(LibrarySeriesInput(
        id: seriesID, title: "Stale Hero", canonicalURL: URL(string: "https://example.com/stale-hero")!,
        sourceDomain: "example.com", coverImageURL: nil, status: "Ongoing", synopsis: "Locally saved",
        latestKnownChapterLabel: nil, libraryState: .planned, chapters: []
    ), context: .seriesDetail)
    let model = SearchOverlayViewModel(libraryProvider: repository, searchHistoryManager: repository)
    await model.load()
    model.query = "stale hero"
    let saved = try #require(model.suggestions.first { $0.kind == .librarySeries })
    // Remove the real stored record after Search has taken its one-time snapshot.
    try await repository.removeFromLibrary(seriesID: seriesID)
    var router = AppRouter(activeSheet: .search)

    #expect(model.select(saved, router: &router) == nil)
    let pendingSeriesID = router.consumePendingLibrarySeriesID()
    let routedID = try #require(pendingSeriesID)
    #expect(routedID == seriesID)
    #expect(await repository.seriesDetail(for: routedID) == nil)
    #expect(router.selectedTab == .library)
    #expect(router.activeSheet == nil)
    #expect(router.presentedBrowser == nil)
    #expect(try await repository.recentSearchHistory(limit: 12).isEmpty)
    router.openLibraryRoot()
    #expect(router.pendingLibrarySeriesID == nil)
    #expect(router.presentedBrowser == nil)
}

@Test @MainActor func searchCompositionWithoutProjectionCapabilityKeepsWebSuggestions() async {
    let model = SearchOverlayViewModel(
        suggestionsProvider: MockSearchSuggestionProvider(clipboardURL: nil, recentLinks: [], recentSearches: ["hero news"], commonSites: []),
        libraryProvider: nil
    )
    await model.load()
    model.query = "hero"
    #expect(model.suggestions.map(\.kind) == [.recentSearch, .searchAction])
    #expect(model.libraryItems.isEmpty)
}

@Test func searchSuggestionLegacyValueMutationPreservesTypedLibraryDestination() {
    var browser = SearchSuggestion(kind: .recentSearch, title: "Hero", subtitle: "", value: "hero", systemImage: "magnifyingglass")
    browser.value = "hero news"
    #expect(browser.destination == .browserInput("hero news"))
    let item = searchOverlayItem("Hero")
    var saved = SearchSuggestion(id: item.id, kind: .librarySeries, title: item.title, subtitle: "", destination: .librarySeries(item), systemImage: "books.vertical")
    saved.value = "https://example.com/unrelated"
    #expect(saved.destination == .librarySeries(item))
}

@Test @MainActor func searchCompositionExactCopiedURLKeepsClipboardAndExplicitActionUtilityException() async {
    let copiedURL = "https://example.com/hero/chapter-1"
    let history = SearchOverlayHistorySpy(entries: [
        SearchHistoryEntry(kind: .link, value: copiedURL, displayTitle: "Hero chapter", lastUsedAt: Date())
    ])
    let model = SearchOverlayViewModel(
        suggestionsProvider: MockSearchSuggestionProvider(
            clipboardURL: copiedURL, recentLinks: [copiedURL, copiedURL],
            recentSearches: [copiedURL], commonSites: []
        ),
        searchHistoryManager: history
    )
    await model.load()
    model.query = copiedURL

    // Approved utility exception: these two actions remain visible despite
    // sharing one browser destination; overlapping ordinary history disappears.
    #expect(model.suggestions.map(\.kind) == [.clipboardLink, .searchAction])
    #expect(model.suggestions.first?.destination == .browserInput(copiedURL))
    #expect(model.suggestions.last?.destination == .browserInput(copiedURL))
    #expect(model.suggestions.filter { $0.kind == .clipboardLink }.count == 1)
    #expect(model.suggestions.filter { $0.kind == .searchAction }.count == 1)
    #expect(!model.suggestions.contains { $0.kind == .recentLink || $0.kind == .recentSearch })
}

@Test @MainActor func searchCompositionKeepsClipboardFirstAndWebActionVisible() async {
    let model = SearchOverlayViewModel(
        suggestionsProvider: MockSearchSuggestionProvider(
            clipboardURL: "https://example.com/hero/chapter-1",
            recentLinks: ["https://example.com/hero/recent"],
            recentSearches: ["hero news"], commonSites: []
        ),
        libraryProvider: SearchOverlayLibrarySpy(items: [searchOverlayItem("Hero Returns"), searchOverlayItem("Hero")])
    )
    await model.load()
    model.query = "hero"

    #expect(model.suggestions.map(\.kind) == [.clipboardLink, .librarySeries, .librarySeries, .recentLink, .recentSearch, .searchAction])
    #expect(model.suggestions[1].title == "Hero")
    #expect(model.suggestions[2].title == "Hero Returns")
    #expect(model.suggestions.last?.destination == .browserInput("hero"))
}

@Test @MainActor func searchCompositionLoadsOnceAndReranksWithoutQueryIO() async {
    let library = SearchOverlayLibrarySpy(items: [searchOverlayItem("Hero")])
    let history = SearchOverlayHistorySpy(entries: [])
    let model = SearchOverlayViewModel(libraryProvider: library, searchHistoryManager: history)
    await model.load()
    model.query = "her"
    #expect(model.suggestions.contains { $0.kind == .librarySeries })
    model.query = "unmatched"
    #expect(!model.suggestions.contains { $0.kind == .librarySeries })
    model.query = "Hero"
    await model.load()
    #expect(await library.fetchCount == 1)
    #expect(await history.fetchCount == 1)
}

@Test @MainActor func searchCompositionBoundsLibraryMatchesAndSuppressesEmptyCatalog() async {
    let model = SearchOverlayViewModel(
        suggestionsProvider: MockSearchSuggestionProvider(clipboardURL: nil, recentLinks: [], recentSearches: [], commonSites: []),
        libraryProvider: SearchOverlayLibrarySpy(items: (0..<20).map { searchOverlayItem("Hero \($0)") })
    )
    await model.load()
    #expect(model.suggestions.isEmpty)
    model.query = "  \n"
    #expect(model.suggestions.isEmpty)
    model.query = "hero"
    #expect(model.suggestions.filter { $0.kind == .librarySeries }.count == 5)
    #expect(model.suggestions.last?.kind == .searchAction)
}

@Test @MainActor func searchCompositionDeduplicatesTypedDestinationsAndRetainsWebAction() async {
    let first = searchOverlayItem("Hero")
    let second = searchOverlayItem("Hero")
    let link = "https://example.com/hero"
    let model = SearchOverlayViewModel(
        suggestionsProvider: MockSearchSuggestionProvider(clipboardURL: link, recentLinks: [link, link], recentSearches: ["hero", "hero"], commonSites: []),
        libraryProvider: SearchOverlayLibrarySpy(items: [first, first, second])
    )
    await model.load()
    model.query = "hero"
    let saved = model.suggestions.filter { $0.kind == .librarySeries }
    #expect(Set(saved.map(\.id)) == Set([first.id, second.id]))
    #expect(model.suggestions.filter { $0.destination == .browserInput(link) }.count == 1)
    #expect(model.suggestions.filter { $0.destination == .browserInput("hero") }.count == 1)
    #expect(model.suggestions.last?.kind == .searchAction)
    #expect(model.suggestions.first?.kind == .clipboardLink)
}

@Test @MainActor func searchCompositionAbsentProjectionPreservesWebAndPermittedSites() async {
    let model = SearchOverlayViewModel(
        suggestionsProvider: MockSearchSuggestionProvider(clipboardURL: "https://example.com/unrelated", recentLinks: [], recentSearches: [], commonSites: ["webtoons.com", "tapas.io", "globalcomix.com"]),
        libraryProvider: SearchOverlayLibrarySpy(items: [])
    )
    await model.load()
    #expect(model.suggestions.map(\.value) == ["https://example.com/unrelated", "webtoons.com", "tapas.io", "globalcomix.com"])
    #expect(!model.suggestions.contains { $0.value == "asuracomic.net" })
    model.query = "hero"
    #expect(model.suggestions.map(\.kind) == [.searchAction])
}

@Test @MainActor func selectingLibraryResultDoesNotRecordWebHistory() async throws {
    // URL-shaped title proves saved destinations bypass browser classification.
    let item = searchOverlayItem("https://")
    let history = SearchOverlayHistorySpy(entries: [])
    let model = SearchOverlayViewModel(libraryProvider: SearchOverlayLibrarySpy(items: [item]), searchHistoryManager: history)
    await model.load()
    model.query = "https"
    let suggestion = try #require(model.suggestions.first { $0.kind == .librarySeries })
    var router = AppRouter(activeSheet: .search)
    let recording = model.select(suggestion, router: &router)
    await recording?.value
    #expect(router.selectedTab == .library)
    #expect(router.pendingLibrarySeriesID == item.id)
    #expect(router.activeSheet == nil)
    #expect(router.presentedBrowser == nil)
    #expect(model.validationMessage == nil)
    #expect(await history.recordedInputs.isEmpty)
}

@Test @MainActor func selectingBrowserResultRoutesImmediatelyAndRecordsNormalizedHistory() async {
    let history = SearchOverlayHistorySpy(entries: [])
    let model = SearchOverlayViewModel(searchHistoryManager: history)
    let suggestion = SearchSuggestion(kind: .recentLink, title: "Example", subtitle: "", value: "example.com/hero", systemImage: "globe")
    var router = AppRouter(activeSheet: .search)
    let recording = model.select(suggestion, router: &router)
    #expect(router.presentedBrowser == .url("https://example.com/hero"))
    #expect(router.activeSheet == nil)
    router.openHomeRoot()
    await recording?.value
    #expect(router.presentedBrowser == nil)
    #expect(router.selectedTab == .home)
    let inputs = await history.recordedInputs
    #expect(inputs.count == 1)
    #expect(inputs.first?.kind == .link)
    #expect(inputs.first?.value == "https://example.com/hero")
    #expect(inputs.first?.displayTitle == "Example")
}

@Test @MainActor func searchValidationSurvivesIdenticalQueryBindingAssignmentUntilRealEdit() {
    let model = SearchOverlayViewModel()
    var router = AppRouter(activeSheet: .search)
    let invalidQuery = "https://"
    model.query = invalidQuery
    #expect(model.submit(router: &router) == nil)
    #expect(model.validationMessage == "Enter a complete web address or search phrase.")

    // A TextField can repeat its current binding value around submission/focus.
    // That assignment is not an edit and must not erase visible validation.
    model.query = invalidQuery
    #expect(model.validationMessage == "Enter a complete web address or search phrase.")
    #expect(router.activeSheet == .search)
    #expect(router.presentedBrowser == nil)

    model.query = "https://example.com"
    #expect(model.validationMessage == nil)
}

@Test @MainActor func searchSubmissionValidatesAndClearsFeedbackOnEditing() async {
    let history = SearchOverlayHistorySpy(entries: [])
    let feedback = RecordingInteractionFeedback()
    let model = SearchOverlayViewModel(searchHistoryManager: history, interactionFeedback: feedback)
    var router = AppRouter(activeSheet: .search)
    model.query = "https://"
    let invalid = model.submit(router: &router)
    #expect(invalid == nil)
    #expect(model.validationMessage == "Enter a complete web address or search phrase.")
    #expect(feedback.events == [.userActionWarning])
    #expect(router.activeSheet == .search)
    #expect(router.presentedBrowser == nil)
    #expect(await history.recordedInputs.isEmpty)
    model.query = "  hero news  "
    #expect(model.validationMessage == nil)
    let recording = model.submit(router: &router)
    #expect(router.presentedBrowser == .searchQuery("hero news"))
    await recording?.value
    #expect(await history.recordedInputs.first?.kind == .searchQuery)
    #expect(await history.recordedInputs.first?.value == "hero news")
}

private func searchOverlayItem(_ title: String) -> LibrarySearchItem {
    LibrarySearchItem(id: UUID(), title: title, sourceDomain: "example.com", libraryState: .reading, currentChapterLabel: "Chapter 1", coverImageURL: nil)
}

private actor SearchOverlayLibrarySpy: LibrarySearchProviding {
    let items: [LibrarySearchItem]
    private(set) var fetchCount = 0
    init(items: [LibrarySearchItem]) { self.items = items }
    func librarySearchItems() async -> [LibrarySearchItem] {
        fetchCount += 1
        return items
    }
}

private actor SearchOverlayHistorySpy: SearchHistoryManaging {
    let entries: [SearchHistoryEntry]
    private(set) var fetchCount = 0
    private(set) var recordedInputs: [SearchHistoryInput] = []
    func removeSearchHistory(id: UUID) async throws {}
    func clearSearchHistory() async throws {}
    init(entries: [SearchHistoryEntry]) { self.entries = entries }
    func recentSearchHistory(limit: Int) async throws -> [SearchHistoryEntry] {
        fetchCount += 1
        return Array(entries.prefix(limit))
    }
    func recordSearchHistory(_ input: SearchHistoryInput) async throws {
        recordedInputs.append(input)
    }
}

@Test func savedSearchSubtitleLayoutShowsCompleteContextAtAllTextSizes() {
    let layout = SearchSuggestionRowLayout()

    #expect(layout.subtitleLineLimit(isSaved: true, accessibilityText: false) == nil)
    #expect(layout.subtitleLineLimit(isSaved: true, accessibilityText: true) == nil)
    #expect(layout.subtitleLineLimit(isSaved: false, accessibilityText: false) == 1)
    #expect(layout.subtitleLineLimit(isSaved: false, accessibilityText: true) == nil)
    #expect(layout.minimumHeight == 44)
}

@Test func searchSuggestionEditorialRowsKeepInsetAndMinimumActionSize() {
    let layout = SearchSuggestionRowLayout()

    #expect(layout.minimumHeight == 44)
    #expect(layout.iconWidth == 28)
    #expect(layout.separatorInset == layout.iconWidth + ToonEdgeSpacing.medium * 2)
}

@Test func searchOverlayFirstOpenLayoutKeepsInputInContentHeader() {
    let layout = SearchOverlayFirstOpenLayout.default

    #expect(layout.searchFieldPlacement == .contentHeader)
    #expect(layout.cancelPlacement == .contentHeader)
    #expect(layout.activatesFocusAfterFirstLayoutPass)
}

@Test func searchInputClassifierTreatsHttpLinksAsURLs() {
    let input = SearchInputClassifier.classify("https://example.com/series/chapter-12")

    #expect(input.kind == .url)
    #expect(input.browserStartPoint == .url("https://example.com/series/chapter-12"))
}

@Test func searchValidationRejectsHostlessHTTPURLs() {
    for value in ["https://", "http://", " http:// \n", "https://?chapter=1"] {
        #expect(SearchInputClassifier.validate(value) == .invalidURL)
    }
}

@Test func searchValidationKeepsEmptyInputInert() {
    #expect(SearchInputClassifier.validate("  \n") == .empty)
}

@Test func searchValidationKeepsSupportedDestinations() {
    for value in ["https://example.com/chapter", "example.com/chapter", "localhost:8080/chapter", "192.168.1.20/chapter", "chapter 12", "ftp://example.com"] {
        guard case .valid = SearchInputClassifier.validate(value) else {
            Issue.record("Unexpected invalid input: \(value)")
            continue
        }
    }
}

@Test func searchInputClassifierAddsSchemeForLikelyDomains() {
    let input = SearchInputClassifier.classify("example.com/chapter-12")

    #expect(input.kind == .url)
    #expect(input.browserStartPoint == .url("https://example.com/chapter-12"))
}

@Test func searchInputClassifierTreatsSpacedTextAsSearchQuery() {
    let input = SearchInputClassifier.classify("best new manhwa chapters")

    #expect(input.kind == .searchQuery)
    #expect(input.browserStartPoint == .searchQuery("best new manhwa chapters"))
}

@Test func searchInputClassifierTrimsInputBeforeRouting() {
    let input = SearchInputClassifier.classify("  https://example.com/chapter-12  ")

    #expect(input.kind == .url)
    #expect(input.browserStartPoint == .url("https://example.com/chapter-12"))
}

@Test func searchInputClassifierNormalizesProtocolRelativeLinks() {
    let input = SearchInputClassifier.classify("//example.com/chapter-12")

    #expect(input.kind == .url)
    #expect(input.browserStartPoint == .url("https://example.com/chapter-12"))
}

@Test func searchInputClassifierTreatsLocalhostWithPortAsURL() {
    let input = SearchInputClassifier.classify("localhost:8080/chapter")

    #expect(input.kind == .url)
    #expect(input.browserStartPoint == .url("http://localhost:8080/chapter"))
}

@Test func searchInputClassifierTreatsIPv4AddressAsURL() {
    let input = SearchInputClassifier.classify("192.168.1.20/chapter")

    #expect(input.kind == .url)
    #expect(input.browserStartPoint == .url("http://192.168.1.20/chapter"))
}

@Test func searchInputClassifierAvoidsDottedPhraseFalsePositive() {
    let input = SearchInputClassifier.classify("what happened in ch. 12")

    #expect(input.kind == .searchQuery)
    #expect(input.browserStartPoint == .searchQuery("what happened in ch. 12"))
}

@Test func searchInputClassifierTreatsUnsupportedSchemesAsSearchQueries() {
    let input = SearchInputClassifier.classify("ftp://example.com/chapter")

    #expect(input.kind == .searchQuery)
    #expect(input.browserStartPoint == .searchQuery("ftp://example.com/chapter"))
}

@Test func searchSuggestionsFollowUXPriorityOrder() {
    let provider = MockSearchSuggestionProvider(
        clipboardURL: "https://example.com/copied-chapter",
        recentLinks: ["https://example.com/recent"],
        recentSearches: ["tower fantasy chapter"],
        commonSites: ["webtoons.com"]
    )

    let suggestions = provider.suggestions(matching: "")

    #expect(suggestions.map(\.kind) == [.clipboardLink, .recentLink, .recentSearch, .commonSite])
}

@Test func searchSuggestionsIncludeExplicitSearchActionWhileTyping() {
    let provider = MockSearchSuggestionProvider(
        clipboardURL: nil,
        recentLinks: ["https://example.com/recent"],
        recentSearches: ["tower fantasy chapter"],
        commonSites: ["webtoons.com"]
    )

    let suggestions = provider.suggestions(matching: "moon")

    #expect(suggestions.last?.kind == .searchAction)
    #expect(suggestions.last?.title == "Search for \"moon\"")
}

@Test func historyBackedSuggestionsPrioritizePersistedRecentSearchesOverStaticHistory() {
    let provider = SearchHistoryBackedSuggestionProvider(
        baseProvider: MockSearchSuggestionProvider(
            clipboardURL: nil,
            recentLinks: ["https://example.com/recent"],
            recentSearches: ["static query"],
            commonSites: []
        ),
        history: [
            SearchHistoryEntry(
                kind: .searchQuery,
                value: "persisted query",
                displayTitle: "persisted query",
                lastUsedAt: Date(timeIntervalSince1970: 20)
            ),
            SearchHistoryEntry(
                kind: .link,
                value: "https://example.com/stored",
                displayTitle: "Stored Link",
                lastUsedAt: Date(timeIntervalSince1970: 10)
            )
        ]
    )

    let suggestions = provider.suggestions(matching: "")

    #expect(suggestions.map(\.kind) == [.recentLink, .recentSearch, .recentLink, .recentSearch])
    #expect(suggestions[1].value == "persisted query")
}

@Test func commonSiteSuggestionsLabelEnabledPublicProfilesOnly() {
    let provider = MockSearchSuggestionProvider(
        clipboardURL: nil,
        recentLinks: [],
        recentSearches: [],
        commonSites: ["webtoons.com", "asuracomic.net"],
        siteProfileRegistry: .default
    )

    let suggestions = provider.suggestions(matching: "")
    let webtoons = suggestions.first { $0.value == "webtoons.com" }
    let asura = suggestions.first { $0.value == "asuracomic.net" }

    #expect(webtoons?.sourceSupportTier == nil)
    #expect(webtoons?.subtitle == "Open site")
    #expect(asura?.sourceSupportTier == nil)
    #expect(asura?.subtitle == "Open site")
}

@Test func homeSnapshotReportsEmptyWhenAllSectionsAreEmpty() {
    let empty = HomeSnapshot(continueReading: [], recentlyUpdated: [], library: [])
    let populated = HomeSnapshot(
        continueReading: [SeriesSummary(title: "A", subtitle: "Chapter 1", progressPercent: 0.2, hasUnreadUpdates: false)],
        recentlyUpdated: [],
        library: []
    )

    #expect(empty.isEmpty)
    #expect(!populated.isEmpty)
}

@MainActor
@Test func coverArtworkMemoryCacheRetainsLoadedArtworkAcrossCardRecreation() throws {
    let cache = CoverArtworkMemoryCache()
    let url = try #require(URL(string: "https://cdn.example.com/covers/sample.jpg"))
    let data = Data([1, 2, 3, 4])

    #expect(cache.data(for: url) == nil)

    cache.store(data, for: url)

    #expect(cache.data(for: url) == data)
}

@Test func searchSuggestionHistoryProvenanceDefaultsAndStablePersistedIdentity() {
    let legacy = SearchSuggestion(kind: .recentSearch, title: "Hero", subtitle: "", value: "hero", systemImage: "clock")
    let typed = SearchSuggestion(kind: .recentSearch, title: "Hero", subtitle: "", destination: .browserInput("hero"), systemImage: "clock")
    #expect(legacy.historyEntryID == nil)
    #expect(typed.historyEntryID == nil)
    let entry = SearchHistoryEntry(kind: .searchQuery, value: "hero", displayTitle: "Hero", lastUsedAt: Date())
    let provider = SearchHistoryBackedSuggestionProvider(baseProvider: MockSearchSuggestionProvider(), history: [entry], includeBaseHistory: false)
    let rows = provider.suggestions(matching: "")
    #expect(rows.filter { $0.kind == .recentSearch || $0.kind == .recentLink }.count == 1)
    #expect(rows.first { $0.historyEntryID == entry.id }?.id == entry.id)
    #expect(rows.contains { $0.kind == .clipboardLink })
    #expect(rows.contains { $0.kind == .commonSite })
    #expect(provider.suggestions(matching: "hero").last?.kind == .searchAction)
    #expect(SearchHistoryBackedSuggestionProvider(baseProvider: MockSearchSuggestionProvider(), history: []).suggestions(matching: "").contains { $0.kind == .recentSearch && $0.historyEntryID == nil })
}

@MainActor
@Test func searchCompositionHistoryLoadFailurePreservesLibraryAndRetryDoesNotRefetchIt() async {
    let entry = SearchHistoryEntry(kind: .searchQuery, value: "hero old", displayTitle: "Hero old", lastUsedAt: Date())
    let history = SearchOverlayFailingHistoryManager(entry: entry)
    let library = SearchOverlayLibrarySpy(items: [searchOverlayItem("Hero")])
    let model = SearchOverlayViewModel(libraryProvider: library, searchHistoryManager: history)
    await model.load()
    #expect(model.libraryItems.count == 1)
    #expect(model.historyFeedback?.message == "Couldn’t load search history. Try again.")
    #expect(model.historyFeedback?.canRetry == true)
    #expect(!model.suggestions.contains { $0.kind == .recentSearch || $0.kind == .recentLink })
    model.query = "hero"
    #expect(model.suggestions.contains { $0.kind == .librarySeries })
    #expect(model.suggestions.last?.kind == .searchAction)
    await model.retryHistoryOperation()
    #expect(model.historyFeedback == nil)
    #expect(model.history == [entry])
    #expect(model.suggestions.contains { $0.historyEntryID == entry.id })
    #expect(await library.fetchCount == 1)
    #expect(await history.fetchCount == 2)
    model.dismissHistoryFeedback()
}

private actor SearchOverlayFailingHistoryManager: SearchHistoryManaging {
    enum Failure: Error { case read }
    let entry: SearchHistoryEntry
    private(set) var fetchCount = 0
    init(entry: SearchHistoryEntry) { self.entry = entry }
    func recentSearchHistory(limit: Int) async throws -> [SearchHistoryEntry] {
        fetchCount += 1
        if fetchCount == 1 { throw Failure.read }
        return [entry]
    }
    func recordSearchHistory(_ input: SearchHistoryInput) async throws {}
    func removeSearchHistory(id: UUID) async throws {}
    func clearSearchHistory() async throws {}
}

@Test func searchSuggestionHistoryUsesTimestampThenUUIDWithinKindGroups() {
    let lower = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let higher = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let queryLower = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    let queryHigher = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    let date = Date(timeIntervalSince1970: 10)
    let entries = [
        SearchHistoryEntry(id: higher, kind: .link, value: "https://example.com/b", displayTitle: "B", lastUsedAt: date),
        SearchHistoryEntry(id: queryHigher, kind: .searchQuery, value: "query b", displayTitle: "B", lastUsedAt: Date(timeIntervalSince1970: 20)),
        SearchHistoryEntry(id: lower, kind: .link, value: "https://example.com/a", displayTitle: "A", lastUsedAt: date),
        SearchHistoryEntry(id: queryLower, kind: .searchQuery, value: "query a", displayTitle: "A", lastUsedAt: Date(timeIntervalSince1970: 20)),
        SearchHistoryEntry(kind: .link, value: "https://example.com/new", displayTitle: "New", lastUsedAt: Date(timeIntervalSince1970: 15))
    ]
    let provider = SearchHistoryBackedSuggestionProvider(baseProvider: MockSearchSuggestionProvider(clipboardURL: nil, recentLinks: [], recentSearches: [], commonSites: []), history: entries)
    #expect(provider.suggestions(matching: "").map(\.id) == [entries[4].id, lower, higher, queryLower, queryHigher])
}
