import Foundation

public enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case library
    case downloads
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home: "Home"
        case .library: "Library"
        case .downloads: "Downloads"
        case .settings: "Settings"
        }
    }
}

public enum AppSheet: Equatable, Sendable {
    case search
}

public enum BrowserStartPoint: Equatable, Sendable {
    case url(String)
    case searchQuery(String)

    public var displayText: String {
        switch self {
        case .url(let value), .searchQuery(let value):
            value
        }
    }
}

public struct BrowserRequest: Equatable, Sendable {
    public let startPoint: BrowserStartPoint
    public let url: URL
    public let displayText: String

    public init?(startPoint: BrowserStartPoint) {
        self.startPoint = startPoint

        switch startPoint {
        case .url(let value):
            guard let url = URL(string: value) else {
                return nil
            }
            self.url = url
            self.displayText = url.host() ?? value
        case .searchQuery(let query):
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }

            var components = URLComponents()
            components.scheme = "https"
            components.host = "www.google.com"
            components.path = "/search"
            components.queryItems = [
                URLQueryItem(name: "q", value: trimmed)
            ]

            guard let url = components.url else {
                return nil
            }

            self.url = url
            self.displayText = trimmed
        }
    }
}

public enum BrowserAction: Equatable, Sendable {
    case goBack
    case goForward
    case reload
    case loadURL(URL)
}

public struct BrowserCommand: Equatable, Sendable {
    public let id: UUID
    public let action: BrowserAction

    public init(id: UUID = UUID(), action: BrowserAction) {
        self.id = id
        self.action = action
    }
}

public enum SearchInputKind: Equatable, Sendable {
    case url
    case searchQuery
}

public struct SearchInput: Equatable, Sendable {
    public let rawValue: String
    public let kind: SearchInputKind
    public let normalizedValue: String

    public init(rawValue: String, kind: SearchInputKind, normalizedValue: String) {
        self.rawValue = rawValue
        self.kind = kind
        self.normalizedValue = normalizedValue
    }

    public var browserStartPoint: BrowserStartPoint {
        switch kind {
        case .url:
            .url(normalizedValue)
        case .searchQuery:
            .searchQuery(normalizedValue)
        }
    }
}

public enum SearchInputClassifier {
    public static func classify(_ rawValue: String) -> SearchInput {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        let hasHTTPPrefix = lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")
        let hasProtocolRelativePrefix = lowercased.hasPrefix("//")
        let hasUnsupportedScheme = hasScheme(trimmed) && !hasHTTPPrefix
        let hasSpaces = trimmed.contains { $0.isWhitespace }
        let hasPathSeparator = trimmed.contains("/")
        let hasDomainShape = matches(trimmed, pattern: #"^[a-zA-Z0-9][a-zA-Z0-9-]*(\.[a-zA-Z0-9-]+)+(:[0-9]+)?(/.*)?$"#)
        let hasLocalhostShape = matches(trimmed, pattern: #"^localhost(:[0-9]+)?(/.*)?$"#)
        let hasIPv4Shape = matches(trimmed, pattern: #"^([0-9]{1,3}\.){3}[0-9]{1,3}(:[0-9]+)?(/.*)?$"#)

        var urlScore = 0
        if hasHTTPPrefix { urlScore += 4 }
        if hasProtocolRelativePrefix { urlScore += 4 }
        if hasDomainShape { urlScore += 3 }
        if hasLocalhostShape { urlScore += 3 }
        if hasIPv4Shape { urlScore += 3 }
        if hasPathSeparator { urlScore += 1 }
        if hasSpaces { urlScore -= 3 }
        if hasUnsupportedScheme { urlScore -= 6 }

        if urlScore >= 3 {
            let normalized = normalizedURL(
                trimmed,
                hasHTTPPrefix: hasHTTPPrefix,
                hasProtocolRelativePrefix: hasProtocolRelativePrefix,
                prefersLocalScheme: hasLocalhostShape || hasIPv4Shape
            )
            return SearchInput(rawValue: rawValue, kind: .url, normalizedValue: normalized)
        }

        return SearchInput(rawValue: rawValue, kind: .searchQuery, normalizedValue: trimmed)
    }

    private static func normalizedURL(
        _ value: String,
        hasHTTPPrefix: Bool,
        hasProtocolRelativePrefix: Bool,
        prefersLocalScheme: Bool
    ) -> String {
        if hasHTTPPrefix {
            return value
        }

        if hasProtocolRelativePrefix {
            return "https:\(value)"
        }

        return "\(prefersLocalScheme ? "http" : "https")://\(value)"
    }

    private static func hasScheme(_ value: String) -> Bool {
        matches(value, pattern: #"^[a-zA-Z][a-zA-Z0-9+.-]*://"#)
    }

    private static func matches(_ value: String, pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}

public enum SearchSuggestionKind: Equatable, Sendable {
    case clipboardLink
    case recentLink
    case recentSearch
    case commonSite
    case searchAction
}

public struct SearchSuggestion: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var kind: SearchSuggestionKind
    public var title: String
    public var subtitle: String
    public var value: String
    public var systemImage: String
    public var sourceSupportTier: SiteProfileSupportTier?

    public init(
        id: UUID = UUID(),
        kind: SearchSuggestionKind,
        title: String,
        subtitle: String,
        value: String,
        systemImage: String,
        sourceSupportTier: SiteProfileSupportTier? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.systemImage = systemImage
        self.sourceSupportTier = sourceSupportTier
    }
}

public struct SeriesSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var subtitle: String
    public var coverImageURL: URL?
    public var progressPercent: Double
    public var hasUnreadUpdates: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        coverImageURL: URL? = nil,
        progressPercent: Double,
        hasUnreadUpdates: Bool
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.coverImageURL = coverImageURL
        self.progressPercent = progressPercent
        self.hasUnreadUpdates = hasUnreadUpdates
    }
}

public struct HomeSnapshot: Equatable, Sendable {
    public var continueReading: [SeriesSummary]
    public var recentlyUpdated: [SeriesSummary]
    public var library: [SeriesSummary]

    public init(
        continueReading: [SeriesSummary],
        recentlyUpdated: [SeriesSummary],
        library: [SeriesSummary]
    ) {
        self.continueReading = continueReading
        self.recentlyUpdated = recentlyUpdated
        self.library = library
    }

    public var isEmpty: Bool {
        continueReading.isEmpty && recentlyUpdated.isEmpty && library.isEmpty
    }

    public var showsContinueReadingViewAll: Bool {
        !continueReading.isEmpty
    }
}

public enum HomeContinueReadingBuilder {
    public static func summaries(from snapshot: LibrarySnapshot, maxCount: Int = 4) -> [SeriesSummary] {
        snapshot.series(for: .recent)
            .filter { $0.lastReadAt != nil && $0.currentChapterLabel != nil }
            .prefix(max(0, maxCount))
            .map(homeSummary)
    }

    private static func homeSummary(_ series: LibrarySeriesSummary) -> SeriesSummary {
        let subtitle: String
        if let currentChapterLabel = series.currentChapterLabel {
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
}

public enum LibrarySegment: String, CaseIterable, Identifiable, Equatable, Sendable {
    case recent
    case reading
    case planned
    case dropped
    case completed

    public var id: LibrarySegment { self }

    public var title: String {
        switch self {
        case .recent: "Recent"
        case .reading: "Reading"
        case .planned: "Planned"
        case .dropped: "Dropped"
        case .completed: "Completed"
        }
    }
}

public enum LibraryCollectionState: String, CaseIterable, Equatable, Sendable {
    case reading
    case planned
    case dropped
    case completed
    case archived

    public var title: String {
        switch self {
        case .reading: "Reading"
        case .planned: "Planned"
        case .dropped: "Dropped"
        case .completed: "Completed"
        case .archived: "Dropped"
        }
    }

    public static var userSelectableStates: [LibraryCollectionState] {
        [.reading, .planned, .dropped, .completed]
    }

    public static func decoded(persistedRawValue: String) -> LibraryCollectionState {
        if persistedRawValue == "archived" {
            return .dropped
        }

        return LibraryCollectionState(rawValue: persistedRawValue) ?? .planned
    }
}

public enum LibraryViewMode: String, CaseIterable, Identifiable, Equatable, Sendable {
    case comfortable
    case compact
    case list

    public var id: LibraryViewMode { self }

    public var title: String {
        switch self {
        case .comfortable: "Comfortable"
        case .compact: "Compact"
        case .list: "List"
        }
    }

    public var systemImage: String {
        switch self {
        case .comfortable: "square.grid.2x2"
        case .compact: "rectangle.grid.2x2"
        case .list: "list.bullet"
        }
    }
}

public struct LibraryViewPreferences {
    private let userDefaults: UserDefaults
    private let selectedViewModeKey = "ToonEdge.Library.selectedViewMode"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var selectedViewMode: LibraryViewMode {
        get {
            guard let rawValue = userDefaults.string(forKey: selectedViewModeKey),
                  let mode = LibraryViewMode(rawValue: rawValue) else {
                return .comfortable
            }
            return mode
        }
        nonmutating set {
            userDefaults.set(newValue.rawValue, forKey: selectedViewModeKey)
        }
    }
}

public struct AddToLibraryStatePickerModel: Equatable, Sendable {
    public var title: String
    public var selectedState: LibraryCollectionState

    public init(title: String, context: LibraryAddContext) {
        self.title = title
        self.selectedState = Self.defaultState(for: context)
    }

    public static var availableStates: [LibraryCollectionState] {
        LibraryCollectionState.userSelectableStates
    }

    public static func defaultState(for context: LibraryAddContext) -> LibraryCollectionState {
        switch context {
        case .reader:
            .reading
        case .browser, .seriesDetail:
            .planned
        }
    }

    public mutating func select(_ state: LibraryCollectionState) {
        selectedState = state
    }
}

public struct LibrarySeriesSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var sourceDomain: String
    public var canonicalURL: URL?
    public var coverImageURL: URL?
    public var progressPercent: Double
    public var chaptersRead: Int
    public var totalKnownChapters: Int?
    public var lastReadAt: Date?
    public var libraryState: LibraryCollectionState
    public var hasUnreadUpdates: Bool
    public var isCompleted: Bool
    public var latestChapterLabel: String?
    public var currentChapterLabel: String?

    public init(
        id: UUID = UUID(),
        title: String,
        sourceDomain: String,
        canonicalURL: URL? = nil,
        coverImageURL: URL?,
        progressPercent: Double,
        chaptersRead: Int,
        totalKnownChapters: Int?,
        lastReadAt: Date?,
        libraryState: LibraryCollectionState,
        hasUnreadUpdates: Bool,
        isCompleted: Bool,
        latestChapterLabel: String?,
        currentChapterLabel: String?
    ) {
        self.id = id
        self.title = title
        self.sourceDomain = sourceDomain
        self.canonicalURL = canonicalURL
        self.coverImageURL = coverImageURL
        self.progressPercent = progressPercent
        self.chaptersRead = chaptersRead
        self.totalKnownChapters = totalKnownChapters
        self.lastReadAt = lastReadAt
        self.libraryState = libraryState
        self.hasUnreadUpdates = hasUnreadUpdates
        self.isCompleted = isCompleted
        self.latestChapterLabel = latestChapterLabel
        self.currentChapterLabel = currentChapterLabel
    }

    public var chapterSummaryText: String {
        if let totalKnownChapters {
            "\(chaptersRead)/\(totalKnownChapters) chapters"
        } else {
            "\(chaptersRead) chapters read"
        }
    }
}

public struct LibrarySnapshot: Equatable, Sendable {
    public var series: [LibrarySeriesSummary]
    public var recentReadSeries: [LibrarySeriesSummary]

    public init(series: [LibrarySeriesSummary], recentReadSeries: [LibrarySeriesSummary] = []) {
        self.series = series
        self.recentReadSeries = recentReadSeries
    }

    public var isEmpty: Bool {
        series.isEmpty && recentReadSeries.isEmpty
    }

    public func series(for segment: LibrarySegment) -> [LibrarySeriesSummary] {
        switch segment {
        case .recent:
            deduplicatedRecentSeries
                .filter { $0.lastReadAt != nil || $0.hasUnreadUpdates }
                .sorted { lhs, rhs in
                    switch (lhs.lastReadAt, rhs.lastReadAt) {
                    case let (lhsDate?, rhsDate?):
                        return lhsDate > rhsDate
                    case (_?, nil):
                        return true
                    case (nil, _?):
                        return false
                    case (nil, nil):
                        return lhs.title < rhs.title
                    }
                }
        case .reading:
            series.filter { $0.libraryState == .reading }
        case .planned:
            series.filter { $0.libraryState == .planned }
        case .dropped:
            series.filter { $0.libraryState == .dropped }
        case .completed:
            series.filter { $0.libraryState == .completed }
        }
    }

    private var deduplicatedRecentSeries: [LibrarySeriesSummary] {
        var seenKeys = Set<String>()
        return (recentReadSeries + series).filter { summary in
            seenKeys.insert(summary.libraryIdentityKey).inserted
        }
    }
}

private extension LibrarySeriesSummary {
    var libraryIdentityKey: String {
        if let canonicalURL {
            return "url:\(LibraryIdentityNormalizer.normalizedCanonicalURL(canonicalURL))"
        }

        return "title:\(LibraryIdentityNormalizer.normalizedSourceDomain(sourceDomain)):\(LibraryIdentityNormalizer.normalizedTitle(title))"
    }
}

public enum LibraryIdentityNormalizer {
    public static func normalizedCanonicalURL(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let scheme = components?.scheme?.lowercased()
        let host = components?.host?.lowercased()
        components?.scheme = scheme
        components?.host = host
        components?.query = nil
        components?.fragment = nil

        let normalized = components?.url?.absoluteString ?? url.absoluteString
        return normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
    }

    public static func normalizedSourceDomain(_ sourceDomain: String) -> String {
        sourceDomain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    public static func normalizedTitle(_ title: String) -> String {
        title
            .lowercased()
            .replacingOccurrences(of: #"[\p{P}\p{S}]+"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

public enum SeriesDetailChapterListMode: String, CaseIterable, Identifiable, Equatable, Sendable {
    case recent
    case all

    public var id: SeriesDetailChapterListMode { self }

    public var title: String {
        switch self {
        case .recent: "Recent"
        case .all: "All"
        }
    }
}

public enum ChapterReadState: Equatable, Sendable {
    case new
    case unread
    case inProgress(progressPercent: Double)
    case read

    public var displayLabel: String {
        switch self {
        case .new: "New"
        case .unread: "Unread"
        case .inProgress(let progressPercent):
            "\(Int((progressPercent * 100).rounded()))%"
        case .read: "Read"
        }
    }

    public var isReadableNext: Bool {
        switch self {
        case .new, .unread, .inProgress:
            true
        case .read:
            false
        }
    }
}

public struct ChapterSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var chapterLabel: String
    public var chapterNumber: Double?
    public var sourceURL: URL
    public var readState: ChapterReadState
    public var isDownloaded: Bool
    public var publishedAt: Date?
    public var lastReadAt: Date?
    public var isGeneratedPlaceholder: Bool
    public var isOpenable: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        chapterLabel: String,
        chapterNumber: Double?,
        sourceURL: URL,
        readState: ChapterReadState,
        isDownloaded: Bool,
        publishedAt: Date?,
        lastReadAt: Date? = nil,
        isGeneratedPlaceholder: Bool = false,
        isOpenable: Bool = true
    ) {
        self.id = id
        self.title = title
        self.chapterLabel = chapterLabel
        self.chapterNumber = chapterNumber
        self.sourceURL = sourceURL
        self.readState = readState
        self.isDownloaded = isDownloaded
        self.publishedAt = publishedAt
        self.lastReadAt = lastReadAt
        self.isGeneratedPlaceholder = isGeneratedPlaceholder
        self.isOpenable = isOpenable
    }

    public var downloadLabel: String? {
        isDownloaded ? "Downloaded" : nil
    }
}

public struct SeriesDetailSnapshot: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var status: String
    public var synopsis: String
    public var sourceDomain: String
    public var coverImageURL: URL?
    public var isSaved: Bool
    public var libraryState: LibraryCollectionState
    public var progressPercent: Double
    public var chaptersRead: Int
    public var totalKnownChapters: Int?
    public var hasUnreadUpdates: Bool
    public var chapters: [ChapterSummary]

    public init(
        id: UUID = UUID(),
        title: String,
        status: String,
        synopsis: String,
        sourceDomain: String,
        coverImageURL: URL?,
        isSaved: Bool,
        libraryState: LibraryCollectionState,
        progressPercent: Double,
        chaptersRead: Int,
        totalKnownChapters: Int?,
        hasUnreadUpdates: Bool,
        chapters: [ChapterSummary]
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.synopsis = synopsis
        self.sourceDomain = sourceDomain
        self.coverImageURL = coverImageURL
        self.isSaved = isSaved
        self.libraryState = libraryState
        self.progressPercent = progressPercent
        self.chaptersRead = chaptersRead
        self.totalKnownChapters = totalKnownChapters
        self.hasUnreadUpdates = hasUnreadUpdates
        self.chapters = chapters
    }

    public var primaryChapter: ChapterSummary? {
        chapters.first { chapter in
            if case .inProgress = chapter.readState {
                return true
            }
            return false
        } ?? sortedChaptersNewestFirst.first { $0.readState.isReadableNext }
    }

    public var primaryActionTitle: String {
        guard let primaryChapter else {
            return "All Chapters Read"
        }

        let label = ChapterNumericLabelExtractor.label(for: primaryChapter) ?? primaryChapter.chapterLabel
        if case .inProgress = primaryChapter.readState {
            return "Continue Chapter \(label)"
        }

        return "Start Chapter \(label)"
    }

    public func chapterList(for mode: SeriesDetailChapterListMode) -> [ChapterSummary] {
        switch mode {
        case .recent:
            Array(
                chapters
                    .filter { $0.lastReadAt != nil }
                    .sorted { lhs, rhs in
                        switch (lhs.lastReadAt, rhs.lastReadAt) {
                        case let (lhsDate?, rhsDate?):
                            lhsDate > rhsDate
                        case (_?, nil):
                            true
                        case (nil, _?):
                            false
                        case (nil, nil):
                            lhs.title < rhs.title
                        }
                    }
                    .prefix(4)
            )
        case .all:
            generatedAllChapterList()
        }
    }

    private var sortedChaptersNewestFirst: [ChapterSummary] {
        chapters.sorted { lhs, rhs in
            let lhsNumber = lhs.chapterNumber ?? .leastNonzeroMagnitude
            let rhsNumber = rhs.chapterNumber ?? .leastNonzeroMagnitude

            if lhsNumber == rhsNumber {
                return lhs.title > rhs.title
            }

            return lhsNumber > rhsNumber
        }
    }

    private func generatedAllChapterList() -> [ChapterSummary] {
        let numericChapters = chapters.compactMap { chapter -> (Int, ChapterSummary)? in
            guard let number = ChapterURLInference.integerChapterNumber(
                chapterNumber: chapter.chapterNumber,
                chapterLabel: chapter.chapterLabel,
                title: chapter.title
            ) else { return nil }
            return (number, chapter)
        }
        guard let latest = numericChapters.map(\.0).max() else {
            return chapters.sorted { $0.title < $1.title }
        }

        let knownByNumber = Dictionary(numericChapters, uniquingKeysWith: { existing, _ in existing })
        let earliest = knownByNumber.keys.contains(0) ? 0 : max(1, knownByNumber.keys.min() ?? 1)
        guard earliest <= latest else { return [] }

        return (earliest...latest).map { number in
            if let known = knownByNumber[number] {
                return known
            }

            let knownChapterURLs = numericChapters.map { numericChapter in
                ChapterURLInference.KnownChapter(
                    number: numericChapter.0,
                    sourceURL: numericChapter.1.sourceURL
                )
            }
            let inferredURL = ChapterURLInference.inferredSourceURL(
                forChapter: number,
                knownChapters: knownChapterURLs
            )
            return ChapterSummary(
                title: "Chapter \(number)",
                chapterLabel: "\(number)",
                chapterNumber: Double(number),
                sourceURL: inferredURL ?? URL(string: "about:blank")!,
                readState: .unread,
                isDownloaded: false,
                publishedAt: nil,
                lastReadAt: nil,
                isGeneratedPlaceholder: true,
                isOpenable: inferredURL != nil
            )
        }
    }
}

enum ChapterURLInference {
    struct KnownChapter {
        var number: Int
        var sourceURL: URL
    }

    static func integerChapterNumber(chapterNumber: Double?, chapterLabel: String, title: String) -> Int? {
        if let chapterNumber,
           chapterNumber.rounded(.towardZero) == chapterNumber {
            return Int(chapterNumber)
        }

        if let label = firstNumericToken(in: chapterLabel),
           let number = Int(label) {
            return number
        }

        return firstNumericToken(in: title).flatMap(Int.init)
    }

    static func inferredSourceURL(forChapter number: Int, knownChapters: [KnownChapter]) -> URL? {
        for knownChapter in knownChapters.sorted(by: { abs($0.number - number) < abs($1.number - number) }) {
            let knownLabel = "\(knownChapter.number)"
            let components = knownChapter.sourceURL.pathComponents
            guard components.contains(where: { pathComponentContainsChapterNumber($0, knownLabel: knownLabel) }) else {
                continue
            }

            let escaped = NSRegularExpression.escapedPattern(for: knownLabel)
            let pattern = #"(?<![0-9])"# + escaped + #"(?![0-9])"#
            var urlComponents = URLComponents(url: knownChapter.sourceURL, resolvingAgainstBaseURL: false)
            guard let updatedPath = urlComponents?.path.replacingFirstRegexMatch(pattern: pattern, with: "\(number)"),
                  updatedPath != urlComponents?.path else {
                continue
            }
            urlComponents?.path = updatedPath
            return urlComponents?.url
        }

        return nil
    }

    private static func firstNumericToken(in value: String) -> String? {
        ChapterNumericLabelExtractor.firstNumericToken(in: value)
    }

    private static func pathComponentContainsChapterNumber(_ pathComponent: String, knownLabel: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: knownLabel)
        return pathComponent.range(of: #"(?<![0-9])"# + escaped + #"(?![0-9])"#, options: .regularExpression) != nil
    }
}

public enum ChapterNumericLabelExtractor {
    public static func label(for chapter: ChapterSummary) -> String? {
        label(
            chapterNumber: chapter.chapterNumber,
            chapterLabel: chapter.chapterLabel,
            title: chapter.title
        )
    }

    public static func label(chapterNumber: Double?, chapterLabel: String, title: String) -> String? {
        if let label = firstNumericToken(in: chapterLabel) {
            return label
        }

        if let chapterNumber {
            if chapterNumber.rounded(.towardZero) == chapterNumber {
                return "\(Int(chapterNumber))"
            }
            return String(chapterNumber)
        }

        return firstNumericToken(in: title)
    }

    static func firstNumericToken(in value: String) -> String? {
        let pattern = #"(?<![A-Za-z0-9])([0-9]+(?:\.[0-9]+)?)(?![A-Za-z0-9])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              match.numberOfRanges > 1,
              let tokenRange = Range(match.range(at: 1), in: value) else {
            return nil
        }

        return String(value[tokenRange])
    }
}

private extension String {
    func replacingFirstRegexMatch(pattern: String, with replacement: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, range: range),
              let stringRange = Range(match.range, in: self) else {
            return nil
        }
        var copy = self
        copy.replaceSubrange(stringRange, with: replacement)
        return copy
    }
}

public enum LibraryAddContext: Equatable, Sendable {
    case browser
    case reader
    case seriesDetail
}

public struct LibrarySeriesInput: Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var canonicalURL: URL
    public var sourceDomain: String
    public var coverImageURL: URL?
    public var status: String
    public var synopsis: String
    public var latestKnownChapterLabel: String?
    public var libraryState: LibraryCollectionState?
    public var chapters: [LibraryChapterInput]

    public init(
        id: UUID = UUID(),
        title: String,
        canonicalURL: URL,
        sourceDomain: String,
        coverImageURL: URL?,
        status: String,
        synopsis: String,
        latestKnownChapterLabel: String?,
        libraryState: LibraryCollectionState?,
        chapters: [LibraryChapterInput]
    ) {
        self.id = id
        self.title = title
        self.canonicalURL = canonicalURL
        self.sourceDomain = sourceDomain
        self.coverImageURL = coverImageURL
        self.status = status
        self.synopsis = synopsis
        self.latestKnownChapterLabel = latestKnownChapterLabel
        self.libraryState = libraryState
        self.chapters = chapters
    }
}

public struct LibraryChapterInput: Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var chapterLabel: String
    public var chapterNumber: Double?
    public var sourceURL: URL
    public var previousChapterURL: URL?
    public var nextChapterURL: URL?
    public var imageURLs: [URL]
    public var publishedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        chapterLabel: String,
        chapterNumber: Double?,
        sourceURL: URL,
        previousChapterURL: URL? = nil,
        nextChapterURL: URL? = nil,
        imageURLs: [URL],
        publishedAt: Date?
    ) {
        self.id = id
        self.title = title
        self.chapterLabel = chapterLabel
        self.chapterNumber = chapterNumber
        self.sourceURL = sourceURL
        self.previousChapterURL = previousChapterURL
        self.nextChapterURL = nextChapterURL
        self.imageURLs = imageURLs
        self.publishedAt = publishedAt
    }
}

public struct ContinueReadingTarget: Equatable, Sendable {
    public var seriesID: UUID
    public var chapterID: UUID
    public var sourceURL: URL
    public var progress: ReaderProgress

    public init(seriesID: UUID, chapterID: UUID, sourceURL: URL, progress: ReaderProgress) {
        self.seriesID = seriesID
        self.chapterID = chapterID
        self.sourceURL = sourceURL
        self.progress = progress
    }
}

public enum SearchHistoryKind: String, Equatable, Sendable {
    case link
    case searchQuery
}

public struct SearchHistoryInput: Equatable, Sendable {
    public var kind: SearchHistoryKind
    public var value: String
    public var displayTitle: String
    public var createdAt: Date

    public init(kind: SearchHistoryKind, value: String, displayTitle: String, createdAt: Date = Date()) {
        self.kind = kind
        self.value = value
        self.displayTitle = displayTitle
        self.createdAt = createdAt
    }
}

public struct SearchHistoryEntry: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var kind: SearchHistoryKind
    public var value: String
    public var displayTitle: String
    public var lastUsedAt: Date

    public init(id: UUID = UUID(), kind: SearchHistoryKind, value: String, displayTitle: String, lastUsedAt: Date) {
        self.id = id
        self.kind = kind
        self.value = value
        self.displayTitle = displayTitle
        self.lastUsedAt = lastUsedAt
    }
}

public struct RecentReadingInput: Equatable, Sendable {
    public var seriesID: UUID
    public var chapterID: UUID
    public var seriesTitle: String
    public var seriesURL: URL
    public var sourceDomain: String
    public var coverImageURL: URL?
    public var chapterTitle: String
    public var chapterLabel: String
    public var sourceURL: URL
    public var imageURLs: [URL]
    public var progress: ReaderProgress
    public var readAt: Date

    public init(
        seriesID: UUID,
        chapterID: UUID,
        seriesTitle: String,
        seriesURL: URL,
        sourceDomain: String,
        coverImageURL: URL? = nil,
        chapterTitle: String,
        chapterLabel: String,
        sourceURL: URL,
        imageURLs: [URL],
        progress: ReaderProgress,
        readAt: Date = Date()
    ) {
        self.seriesID = seriesID
        self.chapterID = chapterID
        self.seriesTitle = seriesTitle
        self.seriesURL = seriesURL
        self.sourceDomain = sourceDomain
        self.coverImageURL = coverImageURL
        self.chapterTitle = chapterTitle
        self.chapterLabel = chapterLabel
        self.sourceURL = sourceURL
        self.imageURLs = imageURLs
        self.progress = progress
        self.readAt = readAt
    }
}

public struct DownloadSummary: Equatable, Sendable {
    public var cachedItemCount: Int
    public var recentItemCount: Int
    public var retainedItemCount: Int
    public var totalEstimatedBytes: Int64
    public var totalMeasuredBytes: Int64
    public var storageDescription: String

    public init(
        cachedItemCount: Int,
        storageDescription: String,
        recentItemCount: Int? = nil,
        retainedItemCount: Int = 0,
        totalEstimatedBytes: Int64 = 0,
        totalMeasuredBytes: Int64 = 0
    ) {
        self.cachedItemCount = cachedItemCount
        self.recentItemCount = recentItemCount ?? cachedItemCount
        self.retainedItemCount = retainedItemCount
        self.totalEstimatedBytes = totalEstimatedBytes
        self.totalMeasuredBytes = totalMeasuredBytes
        self.storageDescription = storageDescription
    }

    public static func storageDescription(for bytes: Int64, qualifier: String = "estimated") -> String {
        guard bytes > 0 else {
            return "No local storage tracked"
        }

        let value = Double(bytes)
        let kibibyte = 1_024.0
        let mebibyte = kibibyte * 1_024.0

        if value < kibibyte {
            return "\(bytes) B \(qualifier)"
        }

        if value < mebibyte {
            return "\(formatted(value / kibibyte)) KB \(qualifier)"
        }

        return "\(formatted(value / mebibyte)) MB \(qualifier)"
    }

    private static func formatted(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
    }
}

public enum CacheRetentionState: String, Equatable, Sendable {
    case recent
    case retained

    public var title: String {
        switch self {
        case .recent: "Recent"
        case .retained: "Retained"
        }
    }
}

public enum CacheActionResult: Equatable, Sendable {
    case recent
    case retained
    case unchanged
    case removed
    case notFound
}

public struct CacheActionFeedback: Equatable, Sendable {
    public var result: CacheActionResult?
    public var message: String
    public var isFailure: Bool

    public init(result: CacheActionResult?, message: String, isFailure: Bool) {
        self.result = result
        self.message = message
        self.isFailure = isFailure
    }

    public static func success(_ result: CacheActionResult) -> CacheActionFeedback {
        CacheActionFeedback(result: result, message: message(for: result), isFailure: false)
    }

    public static func failure(_ message: String = "Cache action failed. Try again.") -> CacheActionFeedback {
        CacheActionFeedback(result: nil, message: message, isFailure: true)
    }

    private static func message(for result: CacheActionResult) -> String {
        switch result {
        case .recent:
            return "Chapter cache updated."
        case .retained:
            return "Chapter retained offline."
        case .unchanged:
            return "Cache state already up to date."
        case .removed:
            return "Cached chapter removed."
        case .notFound:
            return "Cached chapter was not found."
        }
    }
}

public enum CacheStorageState: Equatable, Sendable {
    case fileBacked
    case metadataOnlyMissingFiles
    case empty
}

public struct CacheMetadataInput: Equatable, Sendable {
    public var sourceURL: URL
    public var seriesTitle: String
    public var chapterTitle: String
    public var chapterLabel: String?
    public var imageCount: Int
    public var estimatedStorageBytes: Int64
    public var retentionState: CacheRetentionState
    public var cachedAt: Date

    public init(
        sourceURL: URL,
        seriesTitle: String,
        chapterTitle: String,
        chapterLabel: String?,
        imageCount: Int,
        estimatedStorageBytes: Int64,
        retentionState: CacheRetentionState,
        cachedAt: Date = Date()
    ) {
        self.sourceURL = sourceURL
        self.seriesTitle = seriesTitle
        self.chapterTitle = chapterTitle
        self.chapterLabel = chapterLabel
        self.imageCount = max(0, imageCount)
        self.estimatedStorageBytes = max(0, estimatedStorageBytes)
        self.retentionState = retentionState
        self.cachedAt = cachedAt
    }
}

public struct CacheMetadataEntry: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var sourceURL: URL
    public var seriesTitle: String
    public var chapterTitle: String
    public var chapterLabel: String?
    public var imageCount: Int
    public var estimatedStorageBytes: Int64
    public var retentionState: CacheRetentionState
    public var cachedAt: Date

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        seriesTitle: String,
        chapterTitle: String,
        chapterLabel: String?,
        imageCount: Int,
        estimatedStorageBytes: Int64,
        retentionState: CacheRetentionState,
        cachedAt: Date
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.seriesTitle = seriesTitle
        self.chapterTitle = chapterTitle
        self.chapterLabel = chapterLabel
        self.imageCount = imageCount
        self.estimatedStorageBytes = estimatedStorageBytes
        self.retentionState = retentionState
        self.cachedAt = cachedAt
    }
}

public enum ChapterUpdateComparisonResult: Equatable, Sendable {
    case same
    case newerAvailable
    case changed
}

public enum ChapterUpdateComparison {
    public static func compare(storedLatest: String?, fetchedLatest: String?) -> ChapterUpdateComparisonResult {
        let stored = normalizedLabel(storedLatest)
        let fetched = normalizedLabel(fetchedLatest)

        guard let fetched, !fetched.isEmpty else {
            return .same
        }

        guard let stored, !stored.isEmpty else {
            return .newerAvailable
        }

        if stored == fetched {
            return .same
        }

        if let storedNumber = firstChapterNumber(in: stored),
           let fetchedNumber = firstChapterNumber(in: fetched) {
            return fetchedNumber > storedNumber ? .newerAvailable : .same
        }

        return .changed
    }

    private static func normalizedLabel(_ label: String?) -> String? {
        label?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func firstChapterNumber(in label: String) -> Double? {
        guard let range = label.range(of: #"[0-9]+(\.[0-9]+)?"#, options: .regularExpression) else {
            return nil
        }

        return Double(label[range])
    }
}

public struct SeriesLatestChapterSnapshot: Equatable, Sendable {
    public var seriesID: UUID
    public var latestChapterLabel: String?
    public var sourceURL: URL?
    public var checkedAt: Date

    public init(seriesID: UUID, latestChapterLabel: String?, sourceURL: URL?, checkedAt: Date = Date()) {
        self.seriesID = seriesID
        self.latestChapterLabel = latestChapterLabel
        self.sourceURL = sourceURL
        self.checkedAt = checkedAt
    }
}

public struct ChapterIndexEntry: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var chapterLabel: String
    public var chapterNumber: Double?
    public var sourceURL: URL
    public var publishedAt: Date?
    public var checkedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        chapterLabel: String,
        chapterNumber: Double?,
        sourceURL: URL,
        publishedAt: Date? = nil,
        checkedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.chapterLabel = chapterLabel
        self.chapterNumber = chapterNumber
        self.sourceURL = sourceURL
        self.publishedAt = publishedAt
        self.checkedAt = checkedAt
    }
}

public struct ChapterIndexSnapshot: Equatable, Sendable {
    public var seriesID: UUID
    public var entries: [ChapterIndexEntry]
    public var checkedAt: Date

    public init(seriesID: UUID, entries: [ChapterIndexEntry], checkedAt: Date = Date()) {
        self.seriesID = seriesID
        self.entries = entries
        self.checkedAt = checkedAt
    }

    public var latestChapterLabel: String? {
        entries.max { lhs, rhs in
            (lhs.chapterNumber ?? -1) < (rhs.chapterNumber ?? -1)
        }?.chapterLabel
    }
}

public struct ChapterIndexRefreshOutcome: Equatable, Sendable {
    public var seriesID: UUID
    public var checkedAt: Date
    public var indexedChapterCount: Int
    public var latestChapterLabel: String?
    public var hasUnreadUpdates: Bool
    public var didRefresh: Bool

    public init(
        seriesID: UUID,
        checkedAt: Date = Date(),
        indexedChapterCount: Int,
        latestChapterLabel: String?,
        hasUnreadUpdates: Bool,
        didRefresh: Bool
    ) {
        self.seriesID = seriesID
        self.checkedAt = checkedAt
        self.indexedChapterCount = indexedChapterCount
        self.latestChapterLabel = latestChapterLabel
        self.hasUnreadUpdates = hasUnreadUpdates
        self.didRefresh = didRefresh
    }
}

public struct SeriesUpdateCheckResult: Equatable, Sendable {
    public var seriesID: UUID
    public var latestChapterLabel: String?
    public var hasUnreadUpdates: Bool
    public var checkedAt: Date
    public var comparison: ChapterUpdateComparisonResult

    public init(
        seriesID: UUID,
        latestChapterLabel: String?,
        hasUnreadUpdates: Bool,
        checkedAt: Date,
        comparison: ChapterUpdateComparisonResult
    ) {
        self.seriesID = seriesID
        self.latestChapterLabel = latestChapterLabel
        self.hasUnreadUpdates = hasUnreadUpdates
        self.checkedAt = checkedAt
        self.comparison = comparison
    }
}

public struct LibraryUpdateRefreshResult: Equatable, Sendable {
    public var checkedCount: Int
    public var updatedCount: Int
    public var failedCount: Int

    public init(checkedCount: Int, updatedCount: Int, failedCount: Int) {
        self.checkedCount = checkedCount
        self.updatedCount = updatedCount
        self.failedCount = failedCount
    }
}

public enum ReaderCanvas: String, Equatable, Sendable {
    case charcoal
    case black
    case paper

    public var title: String {
        rawValue.capitalized
    }
}

public enum ReaderDisplayMode: String, CaseIterable, Identifiable, Equatable, Sendable {
    case fitWidth
    case fitScreen

    public var id: Self { self }

    public var title: String {
        switch self {
        case .fitWidth: "Fit Width"
        case .fitScreen: "Fit Screen"
        }
    }
}

public struct ReaderSettings: Equatable, Sendable {
    public var readerCanvas: ReaderCanvas
    public var displayMode: ReaderDisplayMode
    public var isPageSpacingEnabled: Bool
    public var brightnessAid: Double

    public init(
        readerCanvas: ReaderCanvas,
        displayMode: ReaderDisplayMode,
        isPageSpacingEnabled: Bool,
        brightnessAid: Double
    ) {
        self.readerCanvas = readerCanvas
        self.displayMode = displayMode
        self.isPageSpacingEnabled = isPageSpacingEnabled
        self.brightnessAid = brightnessAid
    }

    public static let `default` = ReaderSettings(
        readerCanvas: .charcoal,
        displayMode: .fitWidth,
        isPageSpacingEnabled: false,
        brightnessAid: 0
    )
}

public struct ReaderProgress: Codable, Equatable, Sendable {
    public var currentImageIndex: Int
    public var totalImageCount: Int

    public init(currentImageIndex: Int, totalImageCount: Int) {
        self.currentImageIndex = max(0, currentImageIndex)
        self.totalImageCount = max(0, totalImageCount)
    }

    public var fractionComplete: Double {
        guard totalImageCount > 0 else {
            return 0
        }

        if totalImageCount == 1 {
            return currentImageIndex == 0 ? 1 : 0
        }

        return min(1, max(0, Double(currentImageIndex) / Double(totalImageCount - 1)))
    }
}

public struct MockChapter: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var sourceURL: URL

    public init(id: UUID = UUID(), title: String, sourceURL: URL) {
        self.id = id
        self.title = title
        self.sourceURL = sourceURL
    }

    public static let sample = MockChapter(
        id: UUID(uuidString: "7D51643A-6F2D-4C5E-A098-A34AE8A63CA1")!,
        title: "Chapter 12",
        sourceURL: URL(string: "https://example.com/series/chapter-12")!
    )
}

public enum ReaderLaunchOrigin: Equatable, Sendable {
    case direct
    case browser
    case homeContinueReading
    case library(seriesID: UUID)
}

public enum ReaderChapterDirection: Equatable, Sendable {
    case previous
    case next

    public var failureMessage: String {
        switch self {
        case .previous:
            "Could not open previous chapter in Reader."
        case .next:
            "Could not open next chapter in Reader."
        }
    }
}

public enum AdjacentChapterLoadState: Equatable, Sendable {
    case idle
    case loading(ReaderChapterDirection)
    case failed(ReaderChapterDirection, message: String)
}

public enum CanonicalSeriesURLResolver {
    public static func seriesURL(for sourceURL: URL) -> URL {
        let components = sourceURL.pathComponents

        if let comicsIndex = components.firstIndex(of: "comics"),
           components.indices.contains(comicsIndex + 1) {
            if let chapterIndex = components[(comicsIndex + 2)...].firstIndex(of: "chapter") {
                return url(sourceURL, keepingPathComponentsThrough: chapterIndex - 1)
            }

            return url(sourceURL, keepingPathComponentsThrough: comicsIndex + 1)
        }

        if let seriesIndex = components.firstIndex(of: "series"),
           components.indices.contains(seriesIndex + 1) {
            return url(sourceURL, keepingPathComponentsThrough: seriesIndex + 1)
        }

        let lastComponent = sourceURL.lastPathComponent.lowercased()
        if lastComponent.range(of: #"(^|[^a-z0-9])(chapter|chap|episode|ep)[-_]?[0-9]+|^[0-9]+$"#, options: .regularExpression) != nil {
            return sourceURL.deletingLastPathComponent()
        }

        return sourceURL
    }

    private static func url(_ sourceURL: URL, keepingPathComponentsThrough lastIndex: Int) -> URL {
        var components = URLComponents(url: sourceURL, resolvingAgainstBaseURL: false)
        let retainedComponents = sourceURL.pathComponents.enumerated().compactMap { index, component in
            index <= lastIndex && component != "/" ? component : nil
        }
        components?.path = "/" + retainedComponents.joined(separator: "/")
        components?.query = nil
        components?.fragment = nil
        return components?.url ?? sourceURL.deletingLastPathComponent()
    }
}

public struct MockReaderSession: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var seriesID: UUID
    public var seriesTitle: String
    public var seriesURL: URL
    public var sourceDomain: String
    public var coverImageURL: URL?
    public var seriesStatus: String
    public var seriesSynopsis: String
    public var chapterTitle: String
    public var sourceURL: URL
    public var imageURLs: [URL]
    public var pageMetadata: [ReaderPageMetadata]
    public var previousChapter: MockChapter?
    public var nextChapter: MockChapter?
    public var launchOrigin: ReaderLaunchOrigin
    public var settings: ReaderSettings

    public init(
        id: UUID = UUID(),
        seriesID: UUID = UUID(),
        seriesTitle: String,
        seriesURL: URL? = nil,
        sourceDomain: String? = nil,
        coverImageURL: URL? = nil,
        seriesStatus: String = "Reading",
        seriesSynopsis: String = "Saved from Reader Mode.",
        chapterTitle: String,
        sourceURL: URL,
        imageURLs: [URL],
        pageMetadata: [ReaderPageMetadata] = [],
        previousChapter: MockChapter? = nil,
        nextChapter: MockChapter? = nil,
        launchOrigin: ReaderLaunchOrigin = .direct,
        settings: ReaderSettings = .default
    ) {
        self.id = id
        self.seriesID = seriesID
        self.seriesTitle = seriesTitle
        let resolvedSeriesURL = seriesURL ?? CanonicalSeriesURLResolver.seriesURL(for: sourceURL)
        self.seriesURL = resolvedSeriesURL
        self.sourceDomain = sourceDomain ?? resolvedSeriesURL.host() ?? sourceURL.host() ?? "Unknown source"
        self.coverImageURL = coverImageURL
        self.seriesStatus = seriesStatus
        self.seriesSynopsis = seriesSynopsis
        self.chapterTitle = chapterTitle
        self.sourceURL = sourceURL
        self.imageURLs = imageURLs
        self.pageMetadata = pageMetadata
        self.previousChapter = previousChapter
        self.nextChapter = nextChapter
        self.launchOrigin = launchOrigin
        self.settings = settings
    }

    public static let sample = MockReaderSession(
        id: UUID(uuidString: "26840359-7739-4EAE-92C6-B8C597166760")!,
        seriesID: UUID(uuidString: "A4A029B1-778A-46DF-9B92-2E94378C8E11")!,
        seriesTitle: "Moonlit Edge",
        seriesURL: URL(string: "https://example.com/series")!,
        chapterTitle: "Chapter 12",
        sourceURL: URL(string: "https://example.com/series/chapter-12")!,
        imageURLs: [
            URL(string: "https://picsum.photos/seed/toonedge-12-1/900/1300")!,
            URL(string: "https://picsum.photos/seed/toonedge-12-2/900/1500")!,
            URL(string: "https://picsum.photos/seed/toonedge-12-3/900/1200")!,
            URL(string: "https://picsum.photos/seed/toonedge-12-4/900/1450")!,
            URL(string: "https://picsum.photos/seed/toonedge-12-5/900/1350")!
        ],
        previousChapter: MockChapter(
            id: UUID(uuidString: "2B9D8687-A78F-455C-A09A-3FDD67347C79")!,
            title: "Chapter 11",
            sourceURL: URL(string: "https://example.com/series/chapter-11")!
        ),
        nextChapter: MockChapter(
            id: UUID(uuidString: "C320C77B-6E77-4683-A239-1F97F93548B9")!,
            title: "Chapter 13",
            sourceURL: URL(string: "https://example.com/series/chapter-13")!
        )
    )
}

public struct ReaderPageMetadata: Equatable, Sendable {
    public let pixelWidth: Double
    public let pixelHeight: Double

    public init(pixelWidth: Double, pixelHeight: Double) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}
