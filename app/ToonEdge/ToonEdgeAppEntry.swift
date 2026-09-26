import SwiftUI

@main
struct ToonEdgeAppEntry: App {
    var body: some Scene {
        WindowGroup {
            ToonEdgeRootView(
                dependencies: launchDependencies(),
                initialRouter: launchRouter()
            )
        }
    }

    @MainActor
    private func launchDependencies() -> AppDependencies {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-uiTesting") else {
            return (try? AppDependencies.persistent()) ?? .mock()
        }

        var dependencies = AppDependencies.mock()
        if arguments.contains("-resetSettings") {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: UserDefaultsSettingsRepository.Key.readerCanvas)
            defaults.removeObject(forKey: UserDefaultsSettingsRepository.Key.displayMode)
            defaults.removeObject(forKey: UserDefaultsSettingsRepository.Key.pageSpacing)
            defaults.removeObject(forKey: UserDefaultsSettingsRepository.Key.brightnessAid)
        }
        dependencies.settingsService = UserDefaultsSettingsRepository()
        if arguments.contains("-seedOfflineReader"), let cache = dependencies.chapterAssetCache {
            dependencies.chapterAssetRetainer = UITestFixtureAssetRetainer(assetCache: cache)
            if arguments.contains("-resetOfflineFixture") {
                let directory = cache.chapterDirectory(for: offlineFixtureSession.sourceURL)
                try? FileManager.default.removeItem(at: directory)
            }
        }
        if arguments.contains("-seedDelayedLibrary") {
            dependencies.libraryService = DelayedUITestLibraryService()
        }
        if arguments.contains("-seedDownloads20") {
            let entries = (1...20).map { number in
                CacheMetadataEntry(
                    sourceURL: URL(string: "https://fixture.example/chapter-\(number)")!,
                    seriesTitle: "Fixture Series",
                    chapterTitle: "Fixture Chapter \(number)",
                    chapterLabel: "\(number)",
                    imageCount: 1,
                    estimatedStorageBytes: 1_000,
                    retentionState: .recent,
                    cachedAt: Date(timeIntervalSince1970: Double(number))
                )
            }
            dependencies.cacheMetadataService = MockCacheMetadataService(entries: entries)
            dependencies.cacheStorageMeasurementService = nil
        }
        return dependencies
    }

    private func launchRouter() -> AppRouter {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTesting"),
           let marker = arguments.firstIndex(of: "-openURL"),
           arguments.indices.contains(marker + 1) {
            return AppRouter(presentedBrowser: .url(arguments[marker + 1]))
        }
        guard arguments.contains("-seedOfflineReader") else {
            return AppRouter()
        }
        let session = arguments.contains("-uncachedOfflineFixture")
            ? uncachedOfflineFixtureSession
            : offlineFixtureSession
        return AppRouter(presentedReader: session)
    }
}

private let offlineFixtureSession = MockReaderSession(
    seriesTitle: "Offline Fixture",
    chapterTitle: "Chapter 1",
    sourceURL: URL(string: "https://fixture.example/retained/chapter-1")!,
    imageURLs: (1...3).map { URL(string: "https://images.example.test/offline/00\($0).png")! },
    pageMetadata: (1...3).map { _ in ReaderPageMetadata(pixelWidth: 1, pixelHeight: 1) }
)

private let uncachedOfflineFixtureSession = MockReaderSession(
    seriesTitle: "Offline Fixture",
    chapterTitle: "Chapter 2",
    sourceURL: URL(string: "https://fixture.example/uncached/chapter-2")!,
    imageURLs: [URL(string: "https://images.example.test/uncached/001.png")!],
    pageMetadata: [ReaderPageMetadata(pixelWidth: 1, pixelHeight: 1)]
)

private struct UITestFixtureAssetRetainer: ChapterAssetRetaining {
    let assetCache: any ChapterAssetCaching

    func retainAssets(for session: MockReaderSession) async throws -> Int64 {
        let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==")!
        for imageURL in session.imageURLs {
            try assetCache.store(data, for: imageURL, sourceURL: session.sourceURL)
        }
        return Int64(data.count * session.imageURLs.count)
    }
}

private struct DelayedUITestLibraryService: LibraryProviding {
    func homeSnapshot() async -> HomeSnapshot { await MockLibraryService().homeSnapshot() }

    func librarySnapshot() async -> LibrarySnapshot {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        return await MockLibraryService().librarySnapshot()
    }

    func seriesDetail(for seriesID: UUID) async -> SeriesDetailSnapshot? {
        await MockLibraryService().seriesDetail(for: seriesID)
    }
}
