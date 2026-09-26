Commit list:
471c3f8 Add HTML chapter index fetcher
ea3b0c1 Add chapter index contracts and parser

Stat for Task 1 intended files:
 .../ToonEdgeAppCore/Core/Domain/AppModels.swift    | 400 ++++++++++++++++++++-
 .../Implementations/HTMLChapterIndexFetcher.swift  | 143 ++++++++
 .../Services/Protocols/AppServiceProtocols.swift   |  17 +
 .../ToonEdgeAppCoreTests/UpdateCheckTests.swift    |  39 ++
 4 files changed, 581 insertions(+), 18 deletions(-)

Diff for Task 1 intended files:
diff --git a/app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift b/app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift
index 09d7f9a..cccc46b 100644
--- a/app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift
+++ b/app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift
@@ -287,48 +287,139 @@ public enum HomeContinueReadingBuilder {
             progressPercent: series.progressPercent,
             hasUnreadUpdates: series.hasUnreadUpdates
         )
     }
 }
 
 public enum LibrarySegment: String, CaseIterable, Identifiable, Equatable, Sendable {
     case recent
     case reading
     case planned
+    case dropped
+    case completed
 
     public var id: LibrarySegment { self }
 
     public var title: String {
         switch self {
         case .recent: "Recent"
         case .reading: "Reading"
         case .planned: "Planned"
+        case .dropped: "Dropped"
+        case .completed: "Completed"
         }
     }
 }
 
 public enum LibraryCollectionState: String, CaseIterable, Equatable, Sendable {
     case reading
     case planned
+    case dropped
     case completed
     case archived
 
     public var title: String {
         switch self {
         case .reading: "Reading"
         case .planned: "Planned"
+        case .dropped: "Dropped"
         case .completed: "Completed"
-        case .archived: "Archived"
+        case .archived: "Dropped"
+        }
+    }
+
+    public static var userSelectableStates: [LibraryCollectionState] {
+        [.reading, .planned, .dropped, .completed]
+    }
+
+    public static func decoded(persistedRawValue: String) -> LibraryCollectionState {
+        if persistedRawValue == "archived" {
+            return .dropped
+        }
+
+        return LibraryCollectionState(rawValue: persistedRawValue) ?? .planned
+    }
+}
+
+public enum LibraryViewMode: String, CaseIterable, Identifiable, Equatable, Sendable {
+    case comfortable
+    case compact
+    case list
+
+    public var id: LibraryViewMode { self }
+
+    public var title: String {
+        switch self {
+        case .comfortable: "Comfortable"
+        case .compact: "Compact"
+        case .list: "List"
+        }
+    }
+
+    public var systemImage: String {
+        switch self {
+        case .comfortable: "square.grid.2x2"
+        case .compact: "rectangle.grid.2x2"
+        case .list: "list.bullet"
+        }
+    }
+}
+
+public struct LibraryViewPreferences {
+    private let userDefaults: UserDefaults
+    private let selectedViewModeKey = "ToonEdge.Library.selectedViewMode"
+
+    public init(userDefaults: UserDefaults = .standard) {
+        self.userDefaults = userDefaults
+    }
+
+    public var selectedViewMode: LibraryViewMode {
+        get {
+            guard let rawValue = userDefaults.string(forKey: selectedViewModeKey),
+                  let mode = LibraryViewMode(rawValue: rawValue) else {
+                return .comfortable
+            }
+            return mode
+        }
+        nonmutating set {
+            userDefaults.set(newValue.rawValue, forKey: selectedViewModeKey)
         }
     }
 }
 
+public struct AddToLibraryStatePickerModel: Equatable, Sendable {
+    public var title: String
+    public var selectedState: LibraryCollectionState
+
+    public init(title: String, context: LibraryAddContext) {
+        self.title = title
+        self.selectedState = Self.defaultState(for: context)
+    }
+
+    public static var availableStates: [LibraryCollectionState] {
+        LibraryCollectionState.userSelectableStates
+    }
+
+    public static func defaultState(for context: LibraryAddContext) -> LibraryCollectionState {
+        switch context {
+        case .reader:
+            .reading
+        case .browser, .seriesDetail:
+            .planned
+        }
+    }
+
+    public mutating func select(_ state: LibraryCollectionState) {
+        selectedState = state
+    }
+}
+
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
@@ -406,20 +497,24 @@ public struct LibrarySnapshot: Equatable, Sendable {
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
+        case .dropped:
+            series.filter { $0.libraryState == .dropped }
+        case .completed:
+            series.filter { $0.libraryState == .completed }
         }
     }
 
     private var deduplicatedRecentSeries: [LibrarySeriesSummary] {
         var seenKeys = Set<String>()
         return (recentReadSeries + series).filter { summary in
             seenKeys.insert(summary.libraryIdentityKey).inserted
         }
     }
 }
@@ -456,30 +551,30 @@ public enum LibraryIdentityNormalizer {
 
     public static func normalizedTitle(_ title: String) -> String {
         title
             .lowercased()
             .replacingOccurrences(of: #"[\p{P}\p{S}]+"#, with: " ", options: .regularExpression)
             .split(whereSeparator: \.isWhitespace)
             .joined(separator: " ")
     }
 }
 
-public enum ChapterListSort: String, CaseIterable, Identifiable, Equatable, Sendable {
-    case newestFirst
-    case oldestFirst
+public enum SeriesDetailChapterListMode: String, CaseIterable, Identifiable, Equatable, Sendable {
+    case recent
+    case all
 
-    public var id: ChapterListSort { self }
+    public var id: SeriesDetailChapterListMode { self }
 
     public var title: String {
         switch self {
-        case .newestFirst: "Newest"
-        case .oldestFirst: "Oldest"
+        case .recent: "Recent"
+        case .all: "All"
         }
     }
 }
 
 public enum ChapterReadState: Equatable, Sendable {
     case new
     case unread
     case inProgress(progressPercent: Double)
     case read
 
@@ -505,39 +600,48 @@ public enum ChapterReadState: Equatable, Sendable {
 
 public struct ChapterSummary: Identifiable, Equatable, Sendable {
     public let id: UUID
     public var title: String
     public var chapterLabel: String
     public var chapterNumber: Double?
     public var sourceURL: URL
     public var readState: ChapterReadState
     public var isDownloaded: Bool
     public var publishedAt: Date?
+    public var lastReadAt: Date?
+    public var isGeneratedPlaceholder: Bool
+    public var isOpenable: Bool
 
     public init(
         id: UUID = UUID(),
         title: String,
         chapterLabel: String,
         chapterNumber: Double?,
         sourceURL: URL,
         readState: ChapterReadState,
         isDownloaded: Bool,
-        publishedAt: Date?
+        publishedAt: Date?,
+        lastReadAt: Date? = nil,
+        isGeneratedPlaceholder: Bool = false,
+        isOpenable: Bool = true
     ) {
         self.id = id
         self.title = title
         self.chapterLabel = chapterLabel
         self.chapterNumber = chapterNumber
         self.sourceURL = sourceURL
         self.readState = readState
         self.isDownloaded = isDownloaded
         self.publishedAt = publishedAt
+        self.lastReadAt = lastReadAt
+        self.isGeneratedPlaceholder = isGeneratedPlaceholder
+        self.isOpenable = isOpenable
     }
 
     public var downloadLabel: String? {
         isDownloaded ? "Downloaded" : nil
     }
 }
 
 public struct SeriesDetailSnapshot: Identifiable, Equatable, Sendable {
     public let id: UUID
     public var title: String
@@ -582,46 +686,227 @@ public struct SeriesDetailSnapshot: Identifiable, Equatable, Sendable {
         self.hasUnreadUpdates = hasUnreadUpdates
         self.chapters = chapters
     }
 
     public var primaryChapter: ChapterSummary? {
         chapters.first { chapter in
             if case .inProgress = chapter.readState {
                 return true
             }
             return false
-        } ?? chapters(sortedBy: .newestFirst).first { $0.readState.isReadableNext }
+        } ?? sortedChaptersNewestFirst.first { $0.readState.isReadableNext }
     }
 
     public var primaryActionTitle: String {
         guard let primaryChapter else {
             return "All Chapters Read"
         }
 
+        let label = ChapterNumericLabelExtractor.label(for: primaryChapter) ?? primaryChapter.chapterLabel
         if case .inProgress = primaryChapter.readState {
-            return "Continue Chapter \(primaryChapter.chapterLabel)"
+            return "Continue Chapter \(label)"
         }
 
-        return "Start Chapter \(primaryChapter.chapterLabel)"
+        return "Start Chapter \(label)"
+    }
+
+    public func chapterList(for mode: SeriesDetailChapterListMode) -> [ChapterSummary] {
+        switch mode {
+        case .recent:
+            Array(
+                chapters
+                    .filter { $0.lastReadAt != nil }
+                    .sorted { lhs, rhs in
+                        switch (lhs.lastReadAt, rhs.lastReadAt) {
+                        case let (lhsDate?, rhsDate?):
+                            lhsDate > rhsDate
+                        case (_?, nil):
+                            true
+                        case (nil, _?):
+                            false
+                        case (nil, nil):
+                            lhs.title < rhs.title
+                        }
+                    }
+                    .prefix(4)
+            )
+        case .all:
+            generatedAllChapterList()
+        }
     }
 
-    public func chapters(sortedBy sort: ChapterListSort) -> [ChapterSummary] {
+    private var sortedChaptersNewestFirst: [ChapterSummary] {
         chapters.sorted { lhs, rhs in
             let lhsNumber = lhs.chapterNumber ?? .leastNonzeroMagnitude
             let rhsNumber = rhs.chapterNumber ?? .leastNonzeroMagnitude
 
             if lhsNumber == rhsNumber {
-                return sort == .newestFirst ? lhs.title > rhs.title : lhs.title < rhs.title
+                return lhs.title > rhs.title
+            }
+
+            return lhsNumber > rhsNumber
+        }
+    }
+
+    private func generatedAllChapterList() -> [ChapterSummary] {
+        let numericChapters = chapters.compactMap { chapter -> (Int, ChapterSummary)? in
+            guard let number = ChapterURLInference.integerChapterNumber(
+                chapterNumber: chapter.chapterNumber,
+                chapterLabel: chapter.chapterLabel,
+                title: chapter.title
+            ) else { return nil }
+            return (number, chapter)
+        }
+        guard let latest = numericChapters.map(\.0).max() else {
+            return chapters.sorted { $0.title < $1.title }
+        }
+
+        let knownByNumber = Dictionary(numericChapters, uniquingKeysWith: { existing, _ in existing })
+        let earliest = knownByNumber.keys.contains(0) ? 0 : max(1, knownByNumber.keys.min() ?? 1)
+        guard earliest <= latest else { return [] }
+
+        return (earliest...latest).map { number in
+            if let known = knownByNumber[number] {
+                return known
+            }
+
+            let knownChapterURLs = numericChapters.map { numericChapter in
+                ChapterURLInference.KnownChapter(
+                    number: numericChapter.0,
+                    sourceURL: numericChapter.1.sourceURL
+                )
+            }
+            let inferredURL = ChapterURLInference.inferredSourceURL(
+                forChapter: number,
+                knownChapters: knownChapterURLs
+            )
+            return ChapterSummary(
+                title: "Chapter \(number)",
+                chapterLabel: "\(number)",
+                chapterNumber: Double(number),
+                sourceURL: inferredURL ?? URL(string: "about:blank")!,
+                readState: .unread,
+                isDownloaded: false,
+                publishedAt: nil,
+                lastReadAt: nil,
+                isGeneratedPlaceholder: true,
+                isOpenable: inferredURL != nil
+            )
+        }
+    }
+}
+
+enum ChapterURLInference {
+    struct KnownChapter {
+        var number: Int
+        var sourceURL: URL
+    }
+
+    static func integerChapterNumber(chapterNumber: Double?, chapterLabel: String, title: String) -> Int? {
+        if let chapterNumber,
+           chapterNumber.rounded(.towardZero) == chapterNumber {
+            return Int(chapterNumber)
+        }
+
+        if let label = firstNumericToken(in: chapterLabel),
+           let number = Int(label) {
+            return number
+        }
+
+        return firstNumericToken(in: title).flatMap(Int.init)
+    }
+
+    static func inferredSourceURL(forChapter number: Int, knownChapters: [KnownChapter]) -> URL? {
+        for knownChapter in knownChapters.sorted(by: { abs($0.number - number) < abs($1.number - number) }) {
+            let knownLabel = "\(knownChapter.number)"
+            let components = knownChapter.sourceURL.pathComponents
+            guard components.contains(where: { pathComponentContainsChapterNumber($0, knownLabel: knownLabel) }) else {
+                continue
+            }
+
+            let escaped = NSRegularExpression.escapedPattern(for: knownLabel)
+            let pattern = #"(?<![0-9])"# + escaped + #"(?![0-9])"#
+            var urlComponents = URLComponents(url: knownChapter.sourceURL, resolvingAgainstBaseURL: false)
+            guard let updatedPath = urlComponents?.path.replacingFirstRegexMatch(pattern: pattern, with: "\(number)"),
+                  updatedPath != urlComponents?.path else {
+                continue
+            }
+            urlComponents?.path = updatedPath
+            return urlComponents?.url
+        }
+
+        return nil
+    }
+
+    private static func firstNumericToken(in value: String) -> String? {
+        ChapterNumericLabelExtractor.firstNumericToken(in: value)
+    }
+
+    private static func pathComponentContainsChapterNumber(_ pathComponent: String, knownLabel: String) -> Bool {
+        let escaped = NSRegularExpression.escapedPattern(for: knownLabel)
+        return pathComponent.range(of: #"(?<![0-9])"# + escaped + #"(?![0-9])"#, options: .regularExpression) != nil
+    }
+}
+
+public enum ChapterNumericLabelExtractor {
+    public static func label(for chapter: ChapterSummary) -> String? {
+        label(
+            chapterNumber: chapter.chapterNumber,
+            chapterLabel: chapter.chapterLabel,
+            title: chapter.title
+        )
+    }
+
+    public static func label(chapterNumber: Double?, chapterLabel: String, title: String) -> String? {
+        if let label = firstNumericToken(in: chapterLabel) {
+            return label
+        }
+
+        if let chapterNumber {
+            if chapterNumber.rounded(.towardZero) == chapterNumber {
+                return "\(Int(chapterNumber))"
             }
+            return String(chapterNumber)
+        }
+
+        return firstNumericToken(in: title)
+    }
+
+    static func firstNumericToken(in value: String) -> String? {
+        let pattern = #"(?<![A-Za-z0-9])([0-9]+(?:\.[0-9]+)?)(?![A-Za-z0-9])"#
+        guard let regex = try? NSRegularExpression(pattern: pattern) else {
+            return nil
+        }
+        let range = NSRange(value.startIndex..<value.endIndex, in: value)
+        guard let match = regex.firstMatch(in: value, range: range),
+              match.numberOfRanges > 1,
+              let tokenRange = Range(match.range(at: 1), in: value) else {
+            return nil
+        }
 
-            return sort == .newestFirst ? lhsNumber > rhsNumber : lhsNumber < rhsNumber
+        return String(value[tokenRange])
+    }
+}
+
+private extension String {
+    func replacingFirstRegexMatch(pattern: String, with replacement: String) -> String? {
+        guard let regex = try? NSRegularExpression(pattern: pattern) else {
+            return nil
+        }
+        let range = NSRange(startIndex..<endIndex, in: self)
+        guard let match = regex.firstMatch(in: self, range: range),
+              let stringRange = Range(match.range, in: self) else {
+            return nil
         }
+        var copy = self
+        copy.replaceSubrange(stringRange, with: replacement)
+        return copy
     }
 }
 
 public enum LibraryAddContext: Equatable, Sendable {
     case browser
     case reader
     case seriesDetail
 }
 
 public struct LibrarySeriesInput: Equatable, Sendable {
@@ -1021,20 +1306,91 @@ public struct SeriesLatestChapterSnapshot: Equatable, Sendable {
     public var checkedAt: Date
 
     public init(seriesID: UUID, latestChapterLabel: String?, sourceURL: URL?, checkedAt: Date = Date()) {
         self.seriesID = seriesID
         self.latestChapterLabel = latestChapterLabel
         self.sourceURL = sourceURL
         self.checkedAt = checkedAt
     }
 }
 
+public struct ChapterIndexEntry: Identifiable, Equatable, Sendable {
+    public var id: UUID
+    public var title: String
+    public var chapterLabel: String
+    public var chapterNumber: Double?
+    public var sourceURL: URL
+    public var publishedAt: Date?
+    public var checkedAt: Date
+
+    public init(
+        id: UUID = UUID(),
+        title: String,
+        chapterLabel: String,
+        chapterNumber: Double?,
+        sourceURL: URL,
+        publishedAt: Date? = nil,
+        checkedAt: Date = Date()
+    ) {
+        self.id = id
+        self.title = title
+        self.chapterLabel = chapterLabel
+        self.chapterNumber = chapterNumber
+        self.sourceURL = sourceURL
+        self.publishedAt = publishedAt
+        self.checkedAt = checkedAt
+    }
+}
+
+public struct ChapterIndexSnapshot: Equatable, Sendable {
+    public var seriesID: UUID
+    public var entries: [ChapterIndexEntry]
+    public var checkedAt: Date
+
+    public init(seriesID: UUID, entries: [ChapterIndexEntry], checkedAt: Date = Date()) {
+        self.seriesID = seriesID
+        self.entries = entries
+        self.checkedAt = checkedAt
+    }
+
+    public var latestChapterLabel: String? {
+        entries.max { lhs, rhs in
+            (lhs.chapterNumber ?? -1) < (rhs.chapterNumber ?? -1)
+        }?.chapterLabel
+    }
+}
+
+public struct ChapterIndexRefreshOutcome: Equatable, Sendable {
+    public var seriesID: UUID
+    public var checkedAt: Date
+    public var indexedChapterCount: Int
+    public var latestChapterLabel: String?
+    public var hasUnreadUpdates: Bool
+    public var didRefresh: Bool
+
+    public init(
+        seriesID: UUID,
+        checkedAt: Date = Date(),
+        indexedChapterCount: Int,
+        latestChapterLabel: String?,
+        hasUnreadUpdates: Bool,
+        didRefresh: Bool
+    ) {
+        self.seriesID = seriesID
+        self.checkedAt = checkedAt
+        self.indexedChapterCount = indexedChapterCount
+        self.latestChapterLabel = latestChapterLabel
+        self.hasUnreadUpdates = hasUnreadUpdates
+        self.didRefresh = didRefresh
+    }
+}
+
 public struct SeriesUpdateCheckResult: Equatable, Sendable {
     public var seriesID: UUID
     public var latestChapterLabel: String?
     public var hasUnreadUpdates: Bool
     public var checkedAt: Date
     public var comparison: ChapterUpdateComparisonResult
 
     public init(
         seriesID: UUID,
         latestChapterLabel: String?,
@@ -1177,31 +1533,39 @@ public enum AdjacentChapterLoadState: Equatable, Sendable {
     case idle
     case loading(ReaderChapterDirection)
     case failed(ReaderChapterDirection, message: String)
 }
 
 public enum CanonicalSeriesURLResolver {
     public static func seriesURL(for sourceURL: URL) -> URL {
         let components = sourceURL.pathComponents
 
         if let comicsIndex = components.firstIndex(of: "comics"),
-           components.indices.contains(comicsIndex + 1),
-           let chapterIndex = components[(comicsIndex + 2)...].firstIndex(of: "chapter") {
-            return url(sourceURL, keepingPathComponentsThrough: chapterIndex - 1)
+           components.indices.contains(comicsIndex + 1) {
+            if let chapterIndex = components[(comicsIndex + 2)...].firstIndex(of: "chapter") {
+                return url(sourceURL, keepingPathComponentsThrough: chapterIndex - 1)
+            }
+
+            return url(sourceURL, keepingPathComponentsThrough: comicsIndex + 1)
         }
 
         if let seriesIndex = components.firstIndex(of: "series"),
            components.indices.contains(seriesIndex + 1) {
             return url(sourceURL, keepingPathComponentsThrough: seriesIndex + 1)
         }
 
-        return sourceURL.deletingLastPathComponent()
+        let lastComponent = sourceURL.lastPathComponent.lowercased()
+        if lastComponent.range(of: #"(^|[^a-z0-9])(chapter|chap|episode|ep)[-_]?[0-9]+|^[0-9]+$"#, options: .regularExpression) != nil {
+            return sourceURL.deletingLastPathComponent()
+        }
+
+        return sourceURL
     }
 
     private static func url(_ sourceURL: URL, keepingPathComponentsThrough lastIndex: Int) -> URL {
         var components = URLComponents(url: sourceURL, resolvingAgainstBaseURL: false)
         let retainedComponents = sourceURL.pathComponents.enumerated().compactMap { index, component in
             index <= lastIndex && component != "/" ? component : nil
         }
         components?.path = "/" + retainedComponents.joined(separator: "/")
         components?.query = nil
         components?.fragment = nil
diff --git a/app/Sources/ToonEdgeAppCore/Core/Services/Implementations/HTMLChapterIndexFetcher.swift b/app/Sources/ToonEdgeAppCore/Core/Services/Implementations/HTMLChapterIndexFetcher.swift
new file mode 100644
index 0000000..a7a0e2d
--- /dev/null
+++ b/app/Sources/ToonEdgeAppCore/Core/Services/Implementations/HTMLChapterIndexFetcher.swift
@@ -0,0 +1,143 @@
+import Foundation
+
+public struct HTMLChapterIndexFetcher: SeriesChapterIndexFetching {
+    private let httpClient: any HTTPDataLoading
+    private let now: @Sendable () -> Date
+
+    public init(
+        httpClient: any HTTPDataLoading = URLSessionHTTPDataLoader(),
+        now: @escaping @Sendable () -> Date = Date.init
+    ) {
+        self.httpClient = httpClient
+        self.now = now
+    }
+
+    public func chapterIndexSnapshot(for series: LibrarySeriesSummary) async throws -> ChapterIndexSnapshot? {
+        guard let url = series.canonicalURL,
+              ["http", "https"].contains(url.scheme?.lowercased()) else {
+            return nil
+        }
+
+        let response = try await httpClient.data(from: url)
+        guard (200..<300).contains(response.statusCode) else {
+            return nil
+        }
+
+        let html = String(decoding: response.data, as: UTF8.self)
+        let snapshot = HTMLChapterIndexParser.parse(
+            html: html,
+            baseURL: url,
+            seriesID: series.id,
+            checkedAt: now()
+        )
+        return snapshot.entries.isEmpty ? nil : snapshot
+    }
+}
+
+public enum HTMLChapterIndexParser {
+    public static func parse(
+        html: String,
+        baseURL: URL,
+        seriesID: UUID,
+        checkedAt: Date = Date()
+    ) -> ChapterIndexSnapshot {
+        let entriesByURL = Dictionary(
+            anchors(in: html).compactMap { anchor -> (String, ChapterIndexEntry)? in
+                guard let sourceURL = URL(string: anchor.href, relativeTo: baseURL)?.absoluteURL,
+                      let number = chapterNumber(in: anchor.searchText) else {
+                    return nil
+                }
+
+                let label = normalizedChapterLabel(from: number)
+                let title = anchor.text.isEmpty ? "Chapter \(label)" : anchor.text
+                return (
+                    sourceURL.absoluteString,
+                    ChapterIndexEntry(
+                        title: title,
+                        chapterLabel: label,
+                        chapterNumber: number,
+                        sourceURL: sourceURL,
+                        checkedAt: checkedAt
+                    )
+                )
+            },
+            uniquingKeysWith: { existing, _ in existing }
+        )
+
+        let entries = entriesByURL.values.sorted {
+            switch ($0.chapterNumber, $1.chapterNumber) {
+            case let (lhs?, rhs?) where lhs != rhs:
+                return lhs < rhs
+            default:
+                return $0.sourceURL.absoluteString < $1.sourceURL.absoluteString
+            }
+        }
+
+        return ChapterIndexSnapshot(seriesID: seriesID, entries: entries, checkedAt: checkedAt)
+    }
+
+    private static func anchors(in html: String) -> [Anchor] {
+        let pattern = #"<a\b[^>]*href\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a>"#
+        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
+            return []
+        }
+
+        let range = NSRange(html.startIndex..<html.endIndex, in: html)
+        return regex.matches(in: html, range: range).compactMap { match in
+            guard match.numberOfRanges >= 3,
+                  let hrefRange = Range(match.range(at: 1), in: html),
+                  let textRange = Range(match.range(at: 2), in: html) else {
+                return nil
+            }
+
+            return Anchor(
+                href: String(html[hrefRange]),
+                text: stripTags(String(html[textRange]))
+            )
+        }
+    }
+
+    private static func chapterNumber(in text: String) -> Double? {
+        let pattern = #"\b(?:chapter|chap|ch)\.?\s*([0-9]+(?:[.-][0-9]+)?)\b|/chapter[-/]([0-9]+(?:[.-][0-9]+)?)\b"#
+        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
+            return nil
+        }
+
+        let range = NSRange(text.startIndex..<text.endIndex, in: text)
+        guard let match = regex.firstMatch(in: text, range: range) else {
+            return nil
+        }
+
+        for index in 1..<match.numberOfRanges {
+            guard let tokenRange = Range(match.range(at: index), in: text) else {
+                continue
+            }
+            return Double(String(text[tokenRange]).replacingOccurrences(of: "-", with: "."))
+        }
+
+        return nil
+    }
+
+    private static func normalizedChapterLabel(from number: Double) -> String {
+        if number == number.rounded(.towardZero) {
+            return "\(Int(number))"
+        }
+        return String(number)
+    }
+
+    private static func stripTags(_ value: String) -> String {
+        value
+            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
+            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
+            .trimmingCharacters(in: .whitespacesAndNewlines)
+    }
+
+    private struct Anchor {
+        var href: String
+        var text: String
+
+        var searchText: String {
+            "\(text) \(href)"
+        }
+    }
+}
diff --git a/app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift b/app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift
index 563c739..a24b039 100644
--- a/app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift
+++ b/app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift
@@ -77,20 +77,37 @@ public enum UpdateCacheDiagnosticEvent: Equatable, Sendable {
 }
 
 public protocol UpdateCacheDiagnosticsLogging: Sendable {
     func log(_ event: UpdateCacheDiagnosticEvent) async
 }
 
 public protocol SeriesLatestChapterFetching: Sendable {
     func latestChapterSnapshot(for series: LibrarySeriesSummary) async throws -> SeriesLatestChapterSnapshot?
 }
 
+public protocol SeriesChapterIndexFetching: Sendable {
+    func chapterIndexSnapshot(for series: LibrarySeriesSummary) async throws -> ChapterIndexSnapshot?
+}
+
+public protocol LibraryChapterIndexManaging: Sendable {
+    func recordAvailableChapters(
+        _ chapters: [ChapterIndexEntry],
+        for seriesID: UUID,
+        indexedAt: Date
+    ) async throws
+}
+
+public protocol SeriesChapterIndexRefreshing: Sendable {
+    func refreshChapterIndex(for series: LibrarySeriesSummary) async -> ChapterIndexRefreshOutcome
+    func refreshChapterIndex(for seriesID: UUID) async -> ChapterIndexRefreshOutcome?
+}
+
 public protocol SeriesUpdateChecking: Sendable {
     func checkForUpdates(series: LibrarySeriesSummary) async throws -> SeriesUpdateCheckResult
 }
 
 public protocol LibraryUpdateRefreshing: Sendable {
     func refreshUpdates() async -> LibraryUpdateRefreshResult
 }
 
 public struct SeriesUpdateChecker: SeriesUpdateChecking {
     private let fetcher: any SeriesLatestChapterFetching
diff --git a/app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift b/app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift
index 0bef216..6dc4919 100644
--- a/app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift
+++ b/app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift
@@ -159,20 +159,59 @@ import Testing
         html: html,
         baseURL: URL(string: "https://unlisted.example/story")!,
         seriesID: UUID(uuidString: "2A0FE80C-4790-47BD-94BD-900AF539B957")!,
         checkedAt: Date(timeIntervalSince1970: 1_700_000_000)
     )
 
     #expect(snapshot?.latestChapterLabel == "2")
     #expect(snapshot?.sourceURL == URL(string: "https://unlisted.example/story/chapter-2")!)
 }
 
+@Test func chapterIndexParserExtractsOrderedChapterLinks() throws {
+    let seriesID = UUID(uuidString: "6E13CFE1-D6BB-4F6A-9CF3-8A01A9E97E01")!
+    let baseURL = try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5"))
+    let html = """
+    <main>
+      <a href="/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/107">The Extra's Academy Survival Guide Chapter 107 - Read Online</a>
+      <a href="/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/106">Chapter 106</a>
+      <a href="/privacy">Privacy Policy</a>
+    </main>
+    """
+
+    let snapshot = HTMLChapterIndexParser.parse(
+        html: html,
+        baseURL: baseURL,
+        seriesID: seriesID,
+        checkedAt: Date(timeIntervalSince1970: 1_700_000_000)
+    )
+
+    #expect(snapshot.seriesID == seriesID)
+    #expect(snapshot.entries.map(\.chapterLabel) == ["106", "107"])
+    #expect(snapshot.entries.map(\.chapterNumber) == [106, 107])
+    #expect(snapshot.entries[1].sourceURL.absoluteString == "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/107")
+    #expect(snapshot.latestChapterLabel == "107")
+}
+
+@Test func chapterIndexParserDeduplicatesSameChapterURL() throws {
+    let seriesID = UUID(uuidString: "CC308F48-53EF-4C5F-96A2-694CF89F10F1")!
+    let baseURL = try #require(URL(string: "https://example.com/series/moonlit-edge"))
+    let html = """
+    <a href="/series/moonlit-edge/chapter-12">Chapter 12</a>
+    <a href="/series/moonlit-edge/chapter-12">Read Chapter 12 Online</a>
+    <a href="/series/moonlit-edge/chapter-13">Chapter 13</a>
+    """
+
+    let snapshot = HTMLChapterIndexParser.parse(html: html, baseURL: baseURL, seriesID: seriesID)
+
+    #expect(snapshot.entries.map(\.chapterLabel) == ["12", "13"])
+}
+
 @Test func htmlLatestChapterFetcherRequestsSeriesCanonicalURL() async throws {
     let canonicalURL = URL(string: "https://example.com/series")!
     let series = LibrarySeriesSummary.updateCheckFixture(latestChapterLabel: "12", canonicalURL: canonicalURL)
     let client = RecordingHTTPDataLoader(
         result: .success(
             HTTPDataResponse(
                 data: Data(#"<a href="/series/chapter-13">Chapter 13</a>"#.utf8),
                 statusCode: 200
             )
         )
