import Testing
@testable import ToonEdgeAppCore

@Test func mockDependenciesExposeStableFeatureData() async {
    let dependencies = AppDependencies.mock()

    let homeSnapshot = await dependencies.libraryService.homeSnapshot()
    let downloads = await dependencies.downloadService.downloadSummary()
    let settings = dependencies.settingsService.currentSettings()

    #expect(homeSnapshot.continueReading.count == 3)
    #expect(homeSnapshot.recentlyUpdated.count == 2)
    #expect(homeSnapshot.library.count == 4)
    #expect(downloads.cachedItemCount == 0)
    #expect(settings.readerCanvas == .charcoal)
}

@MainActor
@Test func persistentDependenciesUseSingleLifecycleRepositoryForLibraryAndProgress() throws {
    let dependencies = try AppDependencies.persistent(inMemory: true, usesModelContextIO: false)

    #expect(dependencies.libraryService is SwiftDataLibraryRepository)
    #expect(dependencies.libraryLifecycleService is SwiftDataLibraryRepository)
    #expect(dependencies.readerProgressRepository is SwiftDataLibraryRepository)
    #expect(dependencies.searchHistoryRecorder is SwiftDataLibraryRepository)
}

@MainActor
@Test func persistentDependenciesExposeLifecycleAndSearchHistoryServices() throws {
    let dependencies = try AppDependencies.persistent(inMemory: true, usesModelContextIO: false)

    #expect(dependencies.libraryLifecycleService != nil)
    #expect(dependencies.searchHistoryRecorder != nil)
    #expect(dependencies.recentReadingRecorder != nil)
}

@MainActor
@Test func persistentDependenciesUseCacheBackedDownloadSummary() throws {
    let dependencies = try AppDependencies.persistent(inMemory: true, usesModelContextIO: false)

    #expect(dependencies.downloadService is SwiftDataLibraryRepository)
    #expect(dependencies.cacheMetadataService is SwiftDataLibraryRepository)
}

@Test func mockDependenciesExposeUpdateRefreshService() {
    let dependencies = AppDependencies.mock()

    #expect(dependencies.updateRefreshService != nil)
}

@MainActor
@Test func persistentDependenciesExposeUpdateRefreshService() throws {
    let dependencies = try AppDependencies.persistent(inMemory: true, usesModelContextIO: false)

    #expect(dependencies.updateRefreshService != nil)
}

@MainActor
@Test func persistentDependenciesExposeAdjacentReaderSessionLoader() throws {
    let dependencies = try AppDependencies.persistent(inMemory: true, usesModelContextIO: false)

    #expect(dependencies.adjacentReaderSessionLoader != nil)
}

@Test func mockBrowserServiceRecordsRequestedStartPoint() async {
    let service = MockBrowserService()
    let startPoint = BrowserStartPoint.searchQuery("tower chapter")

    await service.prepare(startPoint)

    #expect(await service.lastPreparedStartPoint == startPoint)
}

@Test func mockReaderServiceBuildsSessionWithoutExtraction() async throws {
    let service = MockReaderService()
    let session = try await service.mockSession(for: MockChapter.sample)

    #expect(session.chapterTitle == MockChapter.sample.title)
    #expect(session.sourceURL == MockChapter.sample.sourceURL)
    #expect(session.imageURLs.count == MockReaderSession.sample.imageURLs.count)
}
