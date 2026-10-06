import SwiftUI
import SwiftData
import WebKit

/// Installed only by the paired -uiTesting / -searchHistoryFixture UUID flags.
/// The fixture owns a separate sandbox store, cache root, and WebKit data store.
@MainActor
struct SearchHistoryUITestFixture {
    let id: UUID
    let reset: Bool
    let failure: String?
    let arguments: [String]

    init?(arguments: [String]) {
        guard arguments.contains("-uiTesting"),
              let marker = arguments.firstIndex(of: "-searchHistoryFixture"),
              arguments.indices.contains(marker + 1),
              let id = UUID(uuidString: arguments[marker + 1]) else { return nil }
        self.id = id
        self.arguments = arguments
        reset = arguments.contains("-resetSearchHistoryFixture")
        if let marker = arguments.firstIndex(of: "-searchHistoryFailure"), arguments.indices.contains(marker + 1) {
            failure = arguments[marker + 1]
        } else { failure = nil }
    }

    func prepare() async throws -> SearchHistoryFixtureState {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = base.appendingPathComponent("SearchHistoryUITests", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        if reset, FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var dependencies = try AppDependencies.persistent(
            modelStoreURL: root.appendingPathComponent("history.store"),
            cacheRootDirectory: root.appendingPathComponent("assets", isDirectory: true)
        )
        dependencies.searchSuggestionProvider = MockSearchSuggestionProvider(
            clipboardURL: "https://history.example/copied", recentLinks: [], recentSearches: [],
            commonSites: ["history-site.example"]
        )
        // Browser routing still runs through production coordination, using owned HTML.
        dependencies.browserPresentationFixture = .lowConfidence
        // Synthetic saved-row routing must not trigger automatic network refreshes.
        dependencies.chapterIndexRefreshService = nil
        dependencies.updateRefreshService = nil
        dependencies.seriesMetadataService = nil
        if reset {
            let preferences = LibraryViewPreferences()
            preferences.resetOrganization()
            preferences.selectedViewMode = .comfortable
            if let marker = arguments.firstIndex(of: "-libraryDensity"), arguments.indices.contains(marker + 1),
               let density = LibraryViewMode(rawValue: arguments[marker + 1]) {
                preferences.selectedViewMode = density
            }
            if let marker = arguments.firstIndex(of: "-librarySources"), arguments.indices.contains(marker + 1) {
                var query = preferences.collectionQuery
                query.selectedSourceDomains = Set(arguments[marker + 1].split(separator: ",").map(String.init))
                preferences.save(collectionQuery: query)
            }
            try await seed(dependencies)
        }
        let website = HistoryFixtureWebsiteStore(id: id)
        try await website.prepare(reset: reset)
        let state = SearchHistoryFixtureState(dependencies: dependencies, root: root, website: website)
        if reset {
            guard try await managerCount(dependencies) == 15,
                  try ModelContext(dependencies.persistenceContainer!).fetch(FetchDescriptor<StoredSeries>()).count == 2 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try await state.capture()
        }
        dependencies.searchHistoryManager = HistoryFixtureFailureManager(base: dependencies.searchHistoryManager!, failure: failure)
        state.dependencies = dependencies
        return state
    }

    private func managerCount(_ dependencies: AppDependencies) async throws -> Int {
        try await dependencies.searchHistoryManager!.recentSearchHistory(limit: Int.max).count
    }

    private func seed(_ dependencies: AppDependencies) async throws {
        let manager = dependencies.searchHistoryManager!
        for number in 1...15 {
            let value: String
            let kind: SearchHistoryKind
            if number == 2 { value = "https://history.example/recent-link"; kind = .link }
            else if number == 4 { value = "https://history.example/copied"; kind = .link }
            else { value = number == 1 ? "history query alpha" : "history query \(number)"; kind = .searchQuery }
            try await manager.recordSearchHistory(SearchHistoryInput(
                kind: kind, value: value, displayTitle: value, createdAt: Date(timeIntervalSince1970: Double(100 - number))
            ))
        }
        // The public recording input intentionally has no UUID. Only owned fixture rows
        // receive stable IDs through a fresh context after real repository recording.
        let context = ModelContext(dependencies.persistenceContainer!)
        for row in try context.fetch(FetchDescriptor<StoredSearchHistory>()) {
            let number: Int
            if row.value == "history query alpha" { number = 1 }
            else if row.value == "https://history.example/recent-link" { number = 2 }
            else if row.value == "https://history.example/copied" { number = 4 }
            else { number = Int(row.value.split(separator: " ").last!)! }
            row.id = Self.stableID(number)
        }
        try context.save()
        let seriesID = Self.stableID(100)
        let chapterID = Self.stableID(101)
        let sourceURL = URL(string: "https://history.example/saved/chapter-7")!
        let imageURL = URL(string: "https://history.example/owned-panel.bin")!
        let chapter = LibraryChapterInput(
            id: chapterID, title: "Chapter 7", chapterLabel: "7", chapterNumber: 7,
            sourceURL: sourceURL, previousChapterURL: URL(string: "https://history.example/saved/chapter-6"),
            nextChapterURL: URL(string: "https://history.example/saved/chapter-8"), imageURLs: [imageURL],
            publishedAt: Date(timeIntervalSince1970: 7)
        )
        try await dependencies.libraryLifecycleService!.addToLibrary(LibrarySeriesInput(
            id: seriesID, title: "History Saved", canonicalURL: URL(string: "https://history.example/saved")!,
            sourceDomain: "history.example", coverImageURL: nil, status: "Ongoing",
            synopsis: "Synthetic owned persistence sentinel", latestKnownChapterLabel: "8",
            libraryState: .reading, chapters: [chapter]
        ), context: .seriesDetail)
        let progress = ReaderProgress(currentImageIndex: 1, totalImageCount: 3)
        try await dependencies.libraryLifecycleService!.recordReadingProgress(progress, forChapterID: chapterID, at: Date(timeIntervalSince1970: 8))
        try await dependencies.recentReadingRecorder!.recordRecentReading(RecentReadingInput(
            seriesID: seriesID, chapterID: chapterID, seriesTitle: "History Saved",
            seriesURL: URL(string: "https://history.example/saved")!, sourceDomain: "history.example",
            chapterTitle: "Chapter 7", chapterLabel: "7", sourceURL: sourceURL,
            imageURLs: [imageURL], progress: progress, readAt: Date(timeIntervalSince1970: 8)
        ))
        try await dependencies.libraryLifecycleService!.addToLibrary(LibrarySeriesInput(
            id: Self.stableID(102), title: "History Planned", canonicalURL: URL(string: "https://history.example/planned")!,
            sourceDomain: "history.example", coverImageURL: nil, status: "Ongoing", synopsis: "Owned planned sentinel",
            latestKnownChapterLabel: nil, libraryState: .planned, chapters: []
        ), context: .seriesDetail)
        try dependencies.chapterAssetCache!.store(Data("ToonEdge owned synthetic cache sentinel".utf8), for: imageURL, sourceURL: sourceURL)
        _ = try await dependencies.cacheMetadataService.recordCacheMetadata(CacheMetadataInput(
            sourceURL: sourceURL, seriesTitle: "History Saved", chapterTitle: "Chapter 7", chapterLabel: "7",
            imageCount: 1, estimatedStorageBytes: 39, retentionState: .retained, cachedAt: Date(timeIntervalSince1970: 9)
        ))
        await dependencies.settingsService.updateSettings(ReaderSettings(
            readerCanvas: .paper, displayMode: .fitScreen, isPageSpacingEnabled: true, brightnessAid: 0.25
        ))
        dependencies.interactionPreferences.setHapticFeedbackEnabled(false)
    }

    private static func stableID(_ number: Int) -> UUID {
        UUID(uuidString: "13600000-0000-0000-0000-\(String(format: "%012d", number))")!
    }
}

@MainActor
struct SearchHistoryFixtureRoot: View {
    let fixture: SearchHistoryUITestFixture
    @State private var state: SearchHistoryFixtureState?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let state {
                VStack(spacing: 0) {
                    ToonEdgeRootView(dependencies: state.dependencies)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    HistoryFixtureDiagnostics(state: state)
                }
            } else if let errorMessage {
                Text(errorMessage).accessibilityIdentifier("historyFixture.initializationError")
            } else {
                ProgressView("Preparing synthetic history")
            }
        }
        .task {
            guard state == nil, errorMessage == nil else { return }
            do { state = try await fixture.prepare() }
            catch { errorMessage = "Synthetic history fixture initialization failed" }
        }
    }
}

@MainActor
private struct HistoryFixtureDiagnostics: View {
    @ObservedObject var state: SearchHistoryFixtureState
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Capture sentinel") {
                    state.result = "Capturing fixture baseline"
                    Task { await state.captureForUI() }
                }
                    .accessibilityIdentifier("historyFixture.capture").frame(minHeight: 44)
                Button("Verify sentinel") {
                    state.result = "Verifying fixture sentinel"
                    state.historyCount = -1
                    Task { await state.verifyForUI() }
                }
                    .accessibilityIdentifier("historyFixture.verify").frame(minHeight: 44)
            }
            Text(state.result).accessibilityIdentifier("historyFixture.result")
            Text("History records: \(state.historyCount)").accessibilityIdentifier("historyFixture.count")
        }
        .font(.caption2)
        .background(.background)
    }
}

@MainActor
final class SearchHistoryFixtureState: ObservableObject {
    var dependencies: AppDependencies
    private let root: URL
    private let website: HistoryFixtureWebsiteStore
    @Published var result = "Synthetic history ready"
    @Published var historyCount = 0

    init(dependencies: AppDependencies, root: URL, website: HistoryFixtureWebsiteStore) {
        self.dependencies = dependencies; self.root = root; self.website = website
    }

    func capture() async throws {
        try await snapshot().write(to: root.appendingPathComponent("protected-baseline.json"), options: .atomic)
    }
    func captureForUI() async {
        do { try await capture(); result = "Fixture baseline captured" }
        catch { result = "Fixture baseline capture failed" }
    }
    func verifyForUI() async {
        do {
            let current = try await snapshot()
            let baseline = try Data(contentsOf: root.appendingPathComponent("protected-baseline.json"))
            historyCount = try await dependencies.searchHistoryManager!.recentSearchHistory(limit: Int.max).count
            result = current == baseline ? "Protected fixture state unchanged" : "Protected fixture state changed"
        } catch { result = "Fixture verification failed" }
    }

    private func snapshot() async throws -> Data {
        let context = ModelContext(dependencies.persistenceContainer!)
        var rows = try protectedRows(context)
        let settings = dependencies.settingsService.currentSettings()
        let preferences = LibraryViewPreferences()
        let query = preferences.collectionQuery
        rows.append(["settings", settings.readerCanvas.rawValue, settings.displayMode.rawValue,
                     String(settings.isPageSpacingEnabled), String(settings.brightnessAid),
                     String(dependencies.interactionPreferences.isHapticFeedbackEnabled())])
        rows.append(["library presentation", query.segment.rawValue, query.sortKey.rawValue,
                     query.sortDirection.rawValue, query.selectedSourceDomains.sorted().joined(separator: ","),
                     preferences.selectedViewMode.rawValue])
        rows += try cacheByteRows()
        rows.append(try await website.snapshot())
        return try JSONEncoder().encode(rows.sorted { $0.lexicographicallyPrecedes($1) })
    }

    // Foundation directory iteration is synchronous; Swift 6 disallows its iterator
    // inside async functions. Propagate file errors rather than masking a lost cache.
    private func cacheByteRows() throws -> [[String]] {
        let assets = root.appendingPathComponent("assets", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(at: assets, includingPropertiesForKeys: [.isRegularFileKey]) else {
            throw CocoaError(.fileReadUnknown)
        }
        var rows: [[String]] = []
        for case let url as URL in enumerator {
            if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                rows.append(["cache bytes", String(url.path.dropFirst(assets.path.count)), try Data(contentsOf: url).base64EncodedString()])
            }
        }
        return rows
    }

    /// Every protected persistent property is compared, including UUIDs and timestamps.
    private func protectedRows(_ context: ModelContext) throws -> [[String]] {
        func strings(_ fields: Any?...) -> [String] {
            fields.map { value in
                if let date = value as? Date { return String(date.timeIntervalSince1970) }
                return String(describing: value)
            }
        }
        let series = try context.fetch(FetchDescriptor<StoredSeries>()).map { strings($0.id, $0.title, $0.canonicalURLString, $0.sourceDomain, $0.coverImageURLString, $0.status, $0.synopsis, $0.latestKnownChapterLabel, $0.hasUnreadUpdates, $0.libraryStateRaw, $0.isCompleted, $0.lastOpenedChapterID, $0.lastReadAt, $0.createdAt, $0.updatedAt) }
        let chapters = try context.fetch(FetchDescriptor<StoredChapter>()).map { strings($0.id, $0.seriesID, $0.title, $0.chapterLabel, $0.chapterNumber, $0.sourceURLString, $0.previousChapterURLString, $0.nextChapterURLString, $0.imageURLStrings, $0.isDownloaded, $0.publishedAt, $0.cachedAt, $0.updatedAt) }
        let progress = try context.fetch(FetchDescriptor<StoredProgress>()).map { strings($0.id, $0.chapterID, $0.sourceURLString, $0.currentImageIndex, $0.totalImageCount, $0.lastReadOffset, $0.updatedAt) }
        let reading = try context.fetch(FetchDescriptor<StoredRecentReading>()).map { strings($0.seriesID, $0.chapterID, $0.seriesTitle, $0.seriesURLString, $0.sourceDomain, $0.coverImageURLString, $0.chapterTitle, $0.chapterLabel, $0.sourceURLString, $0.imageURLStrings, $0.currentImageIndex, $0.totalImageCount, $0.lastReadAt, $0.updatedAt) }
        let cache = try context.fetch(FetchDescriptor<StoredCacheEntry>()).map { strings($0.id, $0.sourceURLString, $0.seriesTitle, $0.chapterTitle, $0.chapterLabel, $0.imageCount, $0.estimatedStorageBytes, $0.retentionStateRaw, $0.cachedAt, $0.updatedAt) }
        return series + chapters + progress + reading + cache
    }
}

@MainActor
private final class HistoryFixtureFailureManager: SearchHistoryManaging {
    let base: any SearchHistoryManaging
    var failure: String?
    init(base: any SearchHistoryManaging, failure: String?) { self.base = base; self.failure = failure }
    func recordSearchHistory(_ input: SearchHistoryInput) async throws { try await base.recordSearchHistory(input) }
    func recentSearchHistory(limit: Int) async throws -> [SearchHistoryEntry] { try await base.recentSearchHistory(limit: limit) }
    func removeSearchHistory(id: UUID) async throws {
        if failure == "remove-once" { failure = nil; throw CocoaError(.fileWriteUnknown) }
        try await base.removeSearchHistory(id: id)
    }
    func clearSearchHistory() async throws {
        if failure == "clear-once" { failure = nil; throw CocoaError(.fileWriteUnknown) }
        try await base.clearSearchHistory()
    }
}

/// This WebKit store is never used by ordinary browser sessions or other fixture UUIDs.
@MainActor
final class HistoryFixtureWebsiteStore: NSObject, WKNavigationDelegate {
    private let store: WKWebsiteDataStore
    private let webView: WKWebView
    private var navigation: CheckedContinuation<Void, Error>?
    init(id: UUID) {
        store = WKWebsiteDataStore(forIdentifier: id)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = store
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
    }
    func prepare(reset: Bool) async throws {
        if reset {
            await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
            let cookie = HTTPCookie(properties: [.name: "toonedge-owned-sentinel", .value: "fixture-cookie", .domain: "history.example", .path: "/", .expires: Date(timeIntervalSince1970: 4_102_444_800)])!
            await store.httpCookieStore.setCookie(cookie)
        }
        let script = reset ? "localStorage.setItem('toonedge-owned-sentinel', 'fixture-storage');" : ""
        try await withCheckedThrowingContinuation { continuation in
            navigation = continuation
            webView.loadHTMLString("<!doctype html><html><body>Synthetic owned sentinel<script>\(script)</script></body></html>", baseURL: URL(string: "https://history.example/"))
        }
        if reset {
            let localValue = try await webView.evaluateJavaScript("localStorage.getItem('toonedge-owned-sentinel')") as? String
            let cookies = await store.httpCookieStore.allCookies()
            guard localValue == "fixture-storage",
                  cookies.contains(where: { $0.name == "toonedge-owned-sentinel" && $0.value == "fixture-cookie" }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
        }
    }
    func snapshot() async throws -> [String] {
        let value = try await webView.evaluateJavaScript("localStorage.getItem('toonedge-owned-sentinel')")
        let cookies = await store.httpCookieStore.allCookies()
        let cookieRows = cookies.map { [$0.name, $0.value, $0.domain, $0.path, String($0.isSecure), String($0.isHTTPOnly), String($0.expiresDate?.timeIntervalSince1970 ?? 0)].joined(separator: "|") }.sorted()
        return ["isolated website", String(describing: value)] + cookieRows
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.navigation?.resume(); self.navigation = nil
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.navigation?.resume(throwing: error); self.navigation = nil
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.navigation?.resume(throwing: error); self.navigation = nil
    }
}
