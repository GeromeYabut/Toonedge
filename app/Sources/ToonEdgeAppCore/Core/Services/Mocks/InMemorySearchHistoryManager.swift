import Foundation

/// Local mock history with the same identity and ordering rules as persistent history.
public actor InMemorySearchHistoryManager: SearchHistoryManaging {
    private var entriesByValue: [String: SearchHistoryEntry]

    public init(entries: [SearchHistoryEntry] = []) {
        entriesByValue = [:]
        for entry in entries.sorted(by: Self.mostRecentFirst) where entriesByValue[entry.value] == nil {
            entriesByValue[entry.value] = entry
        }
    }

    public func recordSearchHistory(_ input: SearchHistoryInput) async throws {
        entriesByValue[input.value] = SearchHistoryEntry(
            id: entriesByValue[input.value]?.id ?? UUID(), kind: input.kind,
            value: input.value, displayTitle: input.displayTitle, lastUsedAt: input.createdAt
        )
    }

    public func recentSearchHistory(limit: Int) async throws -> [SearchHistoryEntry] {
        guard limit > 0 else { return [] }
        return Array(entriesByValue.values.sorted(by: Self.mostRecentFirst).prefix(limit))
    }

    public func removeSearchHistory(id: UUID) async throws {
        guard let entry = entriesByValue.values.first(where: { $0.id == id }) else { return }
        entriesByValue.removeValue(forKey: entry.value)
    }

    public func clearSearchHistory() async throws {
        entriesByValue.removeAll()
    }

    private static func mostRecentFirst(_ lhs: SearchHistoryEntry, _ rhs: SearchHistoryEntry) -> Bool {
        if lhs.lastUsedAt == rhs.lastUsedAt { return lhs.id.uuidString < rhs.id.uuidString }
        return lhs.lastUsedAt > rhs.lastUsedAt
    }
}
