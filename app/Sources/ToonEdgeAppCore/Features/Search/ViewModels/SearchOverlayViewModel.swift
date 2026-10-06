import Combine
import Foundation

public struct SearchHistoryFeedback: Equatable, Sendable {
    public let message: String
    public let canRetry: Bool
}

/// Owns one search presentation's local snapshot and synchronous result composition.
@MainActor
public final class SearchOverlayViewModel: ObservableObject {
    @Published public var query = "" {
        didSet {
            guard query != oldValue else { return }
            validationMessage = nil
            composeSuggestions()
        }
    }
    @Published public private(set) var validationMessage: String?
    @Published public private(set) var historyFeedback: SearchHistoryFeedback?
    @Published public private(set) var history: [SearchHistoryEntry] = []
    @Published public private(set) var libraryItems: [LibrarySearchItem] = []
    @Published public private(set) var suggestions: [SearchSuggestion] = []

    private let suggestionsProvider: any SearchSuggestionProviding
    private let libraryProvider: (any LibrarySearchProviding)?
    private let searchHistoryManager: (any SearchHistoryManaging)?
    private let interactionFeedback: (any InteractionFeedbackProviding)?
    private let ranker = LibrarySuggestionRanker()
    private var hasStartedLoading = false
    private static let savedResultLimit = 5

    public init(
        suggestionsProvider: any SearchSuggestionProviding = MockSearchSuggestionProvider(),
        libraryProvider: (any LibrarySearchProviding)? = nil,
        searchHistoryManager: (any SearchHistoryManaging)? = nil,
        interactionFeedback: (any InteractionFeedbackProviding)? = nil
    ) {
        self.suggestionsProvider = suggestionsProvider
        self.libraryProvider = libraryProvider
        self.searchHistoryManager = searchHistoryManager
        self.interactionFeedback = interactionFeedback
        composeSuggestions()
    }

    public func load() async {
        guard !hasStartedLoading else { return }
        hasStartedLoading = true
        async let loadedHistory: Void = refreshHistory()
        async let loadedLibrary = libraryProvider?.librarySearchItems() ?? []
        let (_, savedItems) = await (loadedHistory, loadedLibrary)
        guard !Task.isCancelled else {
            hasStartedLoading = false
            return
        }
        libraryItems = savedItems
        composeSuggestions()
    }

    public func retryHistoryOperation() async {
        guard historyFeedback?.canRetry == true else { return }
        await refreshHistory()
    }

    public func dismissHistoryFeedback() {
        historyFeedback = nil
    }

    private func refreshHistory() async {
        guard let searchHistoryManager else { return }
        do {
            let entries = try await searchHistoryManager.recentSearchHistory(limit: 12)
            guard !Task.isCancelled else { return }
            history = entries
            historyFeedback = nil
            composeSuggestions()
        } catch {
            guard !Task.isCancelled else { return }
            historyFeedback = SearchHistoryFeedback(message: "Couldn’t load search history. Try again.", canRetry: true)
        }
    }

    /// Routing is synchronous so an awaited history write cannot replace newer
    /// AppRouter state. The returned task is only the optional history side effect.
    @discardableResult
    public func select(_ suggestion: SearchSuggestion, router: inout AppRouter) -> Task<Void, Never>? {
        switch suggestion.destination {
        case .librarySeries(let item):
            router.dismissSheet()
            router.openLibraryDetail(seriesID: item.id)
            return nil
        case .browserInput(let value):
            return openBrowserInput(value, title: suggestion.title, router: &router)
        }
    }

    @discardableResult
    public func submit(router: inout AppRouter) -> Task<Void, Never>? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return openBrowserInput(trimmed, title: trimmed, router: &router)
    }

    private func openBrowserInput(_ value: String, title: String, router: inout AppRouter) -> Task<Void, Never>? {
        let input: SearchInput
        switch SearchInputClassifier.validate(value) {
        case .empty:
            return nil
        case .invalidURL:
            validationMessage = "Enter a complete web address or search phrase."
            if let interactionFeedback {
                InteractionFeedbackOutcomeReporter(feedback: interactionFeedback)
                    .reportInvalidInput(validationIsVisible: true)
            }
            return nil
        case .valid(let validatedInput):
            input = validatedInput
        }
        router.presentBrowser(input.browserStartPoint)
        guard let searchHistoryManager else { return nil }
        let historyInput = SearchHistoryInput(
            kind: input.kind == .url ? .link : .searchQuery,
            value: input.normalizedValue,
            displayTitle: title
        )
        return Task {
            _ = try? await searchHistoryManager.recordSearchHistory(historyInput)
        }
    }

    private func composeSuggestions() {
        let base = SearchHistoryBackedSuggestionProvider(baseProvider: suggestionsProvider, history: history, includeBaseHistory: searchHistoryManager == nil)
            .suggestions(matching: query)
        let saved = ranker.rank(query: query, items: libraryItems, limit: Self.savedResultLimit).map { item in
            SearchSuggestion(
                id: item.id, kind: .librarySeries, title: item.title,
                subtitle: savedSubtitle(for: item), destination: .librarySeries(item), systemImage: "books.vertical"
            )
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let webAction: SearchSuggestion? = trimmed.isEmpty ? nil : base.last(where: { $0.kind == .searchAction })
            ?? SearchSuggestion(kind: .searchAction, title: "Search for \"\(trimmed)\"", subtitle: "Search the web in ToonEdge", value: trimmed, systemImage: "arrow.right.circle")
        let ordered = base.filter { $0.kind == .clipboardLink } + saved
            + base.filter { $0.kind != .clipboardLink && $0.kind != .searchAction }
        let webIdentity = webAction.map(destinationIdentity)
        var seen = Set<DestinationIdentity>()
        var composed: [SearchSuggestion] = []
        for suggestion in ordered {
            let identity = destinationIdentity(suggestion)
            // Approved utility exception: keep copied-link first and the explicit
            // action last even when they share a browser destination. Ordinary
            // history/site duplicates still collapse, including that destination.
            guard identity != webIdentity || suggestion.kind == .clipboardLink,
                  seen.insert(identity).inserted else { continue }
            composed.append(suggestion)
        }
        if let webAction { composed.append(webAction) }
        suggestions = composed
    }

    private func savedSubtitle(for item: LibrarySearchItem) -> String {
        var components = [item.sourceDomain, item.libraryState.title]
        if let label = item.currentChapterLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
           !label.isEmpty {
            // Bare numeric labels need context; named chapters retain the site's
            // wording (including Episode, Prologue, and an existing Chapter prefix).
            components.append(label.first?.isNumber == true ? "Chapter \(label)" : label)
        }
        return components.joined(separator: " · ")
    }

    private enum DestinationIdentity: Hashable {
        case browserInput(String)
        case librarySeries(UUID)
    }

    private func destinationIdentity(_ suggestion: SearchSuggestion) -> DestinationIdentity {
        switch suggestion.destination {
        case .librarySeries(let item):
            return .librarySeries(item.id)
        case .browserInput(let value):
            return .browserInput(SearchInputClassifier.classify(value).normalizedValue)
        }
    }
}
