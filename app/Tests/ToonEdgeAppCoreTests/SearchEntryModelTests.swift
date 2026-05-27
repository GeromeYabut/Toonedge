import Foundation
import Testing
@testable import ToonEdgeAppCore

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

    #expect(webtoons?.sourceSupportTier == .enabledPublic)
    #expect(webtoons?.subtitle == "Supported reader source")
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
