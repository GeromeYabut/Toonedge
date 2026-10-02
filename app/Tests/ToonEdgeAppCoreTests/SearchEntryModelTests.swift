import Foundation
import Testing
@testable import ToonEdgeAppCore

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
        searchHistoryRecorder: history
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
    let model = SearchOverlayViewModel(libraryProvider: library, searchHistoryRecorder: history)
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
    let model = SearchOverlayViewModel(libraryProvider: SearchOverlayLibrarySpy(items: [item]), searchHistoryRecorder: history)
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
    let model = SearchOverlayViewModel(searchHistoryRecorder: history)
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

@Test @MainActor func searchSubmissionValidatesAndClearsFeedbackOnEditing() async {
    let history = SearchOverlayHistorySpy(entries: [])
    let feedback = RecordingInteractionFeedback()
    let model = SearchOverlayViewModel(searchHistoryRecorder: history, interactionFeedback: feedback)
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

private actor SearchOverlayHistorySpy: SearchHistoryRecording {
    let entries: [SearchHistoryEntry]
    private(set) var fetchCount = 0
    private(set) var recordedInputs: [SearchHistoryInput] = []
    init(entries: [SearchHistoryEntry]) { self.entries = entries }
    func recentSearchHistory(limit: Int) async -> [SearchHistoryEntry] {
        fetchCount += 1
        return Array(entries.prefix(limit))
    }
    func recordSearchHistory(_ input: SearchHistoryInput) async throws {
        recordedInputs.append(input)
    }
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
