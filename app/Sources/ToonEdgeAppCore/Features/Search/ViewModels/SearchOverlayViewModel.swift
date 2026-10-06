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
            clearSuccessFeedback()
            composeSuggestions()
        }
    }
    @Published public private(set) var validationMessage: String?
    @Published public private(set) var historyFeedback: SearchHistoryFeedback? {
        didSet {
            if historyFeedback != nil { historyFeedbackVersion += 1 }
        }
    }
    /// Repeated outcomes still need distinct accessibility announcements.
    @Published public private(set) var historyFeedbackVersion = 0
    @Published public private(set) var isHistoryOperationInFlight = false
    @Published public private(set) var removedHistoryID: UUID?
    @Published public private(set) var history: [SearchHistoryEntry] = []
    @Published public private(set) var libraryItems: [LibrarySearchItem] = []
    @Published public private(set) var suggestions: [SearchSuggestion] = []

    private let suggestionsProvider: any SearchSuggestionProviding
    private let libraryProvider: (any LibrarySearchProviding)?
    private let searchHistoryManager: (any SearchHistoryManaging)?
    private let interactionFeedback: (any InteractionFeedbackProviding)?
    private let ranker = LibrarySuggestionRanker()
    private var hasStartedLoading = false
    private enum HistoryRetry { case remove(UUID), refresh(changed: Bool) }
    private var historyRetry: HistoryRetry?
    private var historyGeneration = 0
    private var removedIDs = Set<UUID>()
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

    public func canRemoveHistory(_ suggestion: SearchSuggestion) -> Bool {
        guard searchHistoryManager != nil,
              suggestion.kind == .recentSearch || suggestion.kind == .recentLink,
              let id = suggestion.historyEntryID else { return false }
        return history.contains { $0.id == id }
    }

    public func removeHistory(for suggestion: SearchSuggestion) async {
        guard canRemoveHistory(suggestion), let id = suggestion.historyEntryID,
              !isHistoryOperationInFlight else { return }
        await removeHistory(id: id)
    }

    public func retryHistoryOperation() async {
        guard historyFeedback?.canRetry == true, let retry = historyRetry,
              !isHistoryOperationInFlight else { return }
        switch retry {
        case .remove(let id):
            await removeHistory(id: id)
        case .refresh(let changed):
            isHistoryOperationInFlight = true
            defer { isHistoryOperationInFlight = false }
            await refreshHistory(changed: changed)
        }
    }

    public func dismissHistoryFeedback() {
        historyFeedback = nil
        historyRetry = nil
    }

    private func clearSuccessFeedback() {
        if historyFeedback?.canRetry == false { dismissHistoryFeedback() }
    }

    private func removeHistory(id: UUID) async {
        guard let searchHistoryManager else { return }
        clearSuccessFeedback()
        isHistoryOperationInFlight = true
        // Invalidate older reads before the repository suspends.
        historyGeneration += 1
        defer { isHistoryOperationInFlight = false }
        do {
            try await searchHistoryManager.removeSearchHistory(id: id)
        } catch {
            historyRetry = .remove(id)
            historyFeedback = SearchHistoryFeedback(message: "Couldn’t remove this item. Try again.", canRetry: true)
            return
        }
        // A committed mutation must be reflected even if its caller was cancelled.
        removedIDs.insert(id)
        history.removeAll { $0.id == id }
        composeSuggestions()
        removedHistoryID = id
        historyRetry = nil
        historyFeedback = SearchHistoryFeedback(message: "Removed from Search History.", canRetry: false)
        await refreshHistory(changed: true, preserveSuccess: true)
    }

    private func refreshHistory(changed: Bool = false, preserveSuccess: Bool = false) async {
        guard let searchHistoryManager else { return }
        historyGeneration += 1
        let generation = historyGeneration
        do {
            let entries = try await searchHistoryManager.recentSearchHistory(limit: 12)
            guard generation == historyGeneration else { return }
            history = entries.filter { !removedIDs.contains($0.id) }
            if !preserveSuccess {
                historyFeedback = nil
                historyRetry = nil
            }
            composeSuggestions()
        } catch {
            guard generation == historyGeneration else { return }
            historyRetry = .refresh(changed: changed)
            historyFeedback = SearchHistoryFeedback(
                message: changed ? "Search history changed, but suggestions couldn’t be refreshed." : "Couldn’t load search history. Try again.",
                canRetry: true
            )
        }
    }

    /// Routing is synchronous so an awaited history write cannot replace newer
    /// AppRouter state. The returned task is only the optional history side effect.
    @discardableResult
    public func select(_ suggestion: SearchSuggestion, router: inout AppRouter) -> Task<Void, Never>? {
        clearSuccessFeedback()
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
        clearSuccessFeedback()
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
