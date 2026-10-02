import Foundation
import Testing
@testable import ToonEdgeAppCore

@Test func updateComparisonDetectsNewerNumericChapter() {
    let result = ChapterUpdateComparison.compare(storedLatest: "12", fetchedLatest: "13")

    #expect(result == .newerAvailable)
}

@Test func updateComparisonDetectsNewerDecimalChapter() {
    let result = ChapterUpdateComparison.compare(storedLatest: "12.5", fetchedLatest: "13.1")

    #expect(result == .newerAvailable)
}

@Test func updateComparisonTreatsChangedNonNumericLabelAsUnknownChange() {
    let result = ChapterUpdateComparison.compare(storedLatest: "Special A", fetchedLatest: "Special B")

    #expect(result == .changed)
}

@Test func updateComparisonDoesNotMarkSameLatestLabelAsUpdate() {
    let result = ChapterUpdateComparison.compare(storedLatest: " Chapter 13 ", fetchedLatest: "chapter 13")

    #expect(result == .same)
}

@Test func updateComparisonDetectsFetchedLabelWhenStoredLabelIsMissing() {
    let result = ChapterUpdateComparison.compare(storedLatest: nil, fetchedLatest: "Chapter 1")

    #expect(result == .newerAvailable)
}

@Test func updateComparisonDoesNotCreateFalseUpdateWhenFetchedLabelIsMissing() {
    let result = ChapterUpdateComparison.compare(storedLatest: "Chapter 12", fetchedLatest: nil)

    #expect(result == .same)
}

@Test func updateComparisonTreatsInvalidChangedLabelsConservatively() {
    let result = ChapterUpdateComparison.compare(storedLatest: "Finale", fetchedLatest: "Special")

    #expect(result == .changed)
}

@Test func updateCheckerRequestsLatestChapterMetadataFromFetcher() async throws {
    let series = LibrarySeriesSummary.updateCheckFixture(latestChapterLabel: "12")
    let fetcher = RecordingLatestChapterFetcher(
        snapshot: SeriesLatestChapterSnapshot(
            seriesID: series.id,
            latestChapterLabel: "13",
            sourceURL: URL(string: "https://example.com/series/chapter-13")!,
            checkedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
    )
    let checker = SeriesUpdateChecker(fetcher: fetcher)

    _ = try await checker.checkForUpdates(series: series)

    #expect(await fetcher.requestedSeriesIDs == [series.id])
}

@Test func updateCheckerMapsNewerFetchedChapterToUnreadUpdates() async throws {
    let series = LibrarySeriesSummary.updateCheckFixture(latestChapterLabel: "12")
    let checker = SeriesUpdateChecker(
        fetcher: RecordingLatestChapterFetcher(
            snapshot: SeriesLatestChapterSnapshot(
                seriesID: series.id,
                latestChapterLabel: "13",
                sourceURL: URL(string: "https://example.com/series/chapter-13")!,
                checkedAt: Date(timeIntervalSince1970: 1_700_000_100)
            )
        )
    )

    let result = try await checker.checkForUpdates(series: series)

    #expect(result.hasUnreadUpdates)
    #expect(result.latestChapterLabel == "13")
    #expect(result.comparison == .newerAvailable)
}

@Test func updateCheckerKeepsSameFetchedChapterWithoutUnreadUpdates() async throws {
    let series = LibrarySeriesSummary.updateCheckFixture(latestChapterLabel: "13")
    let checker = SeriesUpdateChecker(
        fetcher: RecordingLatestChapterFetcher(
            snapshot: SeriesLatestChapterSnapshot(
                seriesID: series.id,
                latestChapterLabel: "13",
                sourceURL: URL(string: "https://example.com/series/chapter-13")!,
                checkedAt: Date(timeIntervalSince1970: 1_700_000_100)
            )
        )
    )

    let result = try await checker.checkForUpdates(series: series)

    #expect(!result.hasUnreadUpdates)
    #expect(result.comparison == .same)
}

@Test func latestChapterParserExtractsHighestNumericChapterLink() throws {
    let html = """
    <a href="/series/chapter-12">Chapter 12</a>
    <a href="/series/chapter-13">Chapter 13</a>
    """

    let snapshot = HTMLLatestChapterParser.parse(
        html: html,
        baseURL: URL(string: "https://example.com/series")!,
        seriesID: UUID(uuidString: "2A0FE80C-4790-47BD-94BD-900AF539B957")!,
        checkedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    #expect(snapshot?.latestChapterLabel == "13")
    #expect(snapshot?.sourceURL == URL(string: "https://example.com/series/chapter-13")!)
}

@Test func latestChapterParserExtractsDecimalChapterLabels() throws {
    let html = """
    <a href="chapter-12">Chapter 12</a>
    <a href="chapter-12-5">Chapter 12.5</a>
    """

    let snapshot = HTMLLatestChapterParser.parse(
        html: html,
        baseURL: URL(string: "https://example.com/list/")!,
        seriesID: UUID(uuidString: "2A0FE80C-4790-47BD-94BD-900AF539B957")!,
        checkedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    #expect(snapshot?.latestChapterLabel == "12.5")
    #expect(snapshot?.sourceURL == URL(string: "https://example.com/list/chapter-12-5")!)
}

@Test func latestChapterParserReturnsNilWithoutChapterLikeLinks() throws {
    let html = """
    <a href="/about">About</a>
    <a href="/news">News</a>
    """

    let snapshot = HTMLLatestChapterParser.parse(
        html: html,
        baseURL: URL(string: "https://example.com/series")!,
        seriesID: UUID(uuidString: "2A0FE80C-4790-47BD-94BD-900AF539B957")!,
        checkedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    #expect(snapshot == nil)
}

@Test func latestChapterParserDoesNotRequireKnownSourceDomain() throws {
    let html = """
    <a href="https://unlisted.example/story/chapter-2">Read Chapter 2</a>
    """

    let snapshot = HTMLLatestChapterParser.parse(
        html: html,
        baseURL: URL(string: "https://unlisted.example/story")!,
        seriesID: UUID(uuidString: "2A0FE80C-4790-47BD-94BD-900AF539B957")!,
        checkedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    #expect(snapshot?.latestChapterLabel == "2")
    #expect(snapshot?.sourceURL == URL(string: "https://unlisted.example/story/chapter-2")!)
}

@Test func chapterIndexParserExtractsOrderedChapterLinks() throws {
    let seriesID = UUID(uuidString: "6E13CFE1-D6BB-4F6A-9CF3-8A01A9E97E01")!
    let baseURL = try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5"))
    let html = """
    <main>
      <a href="/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/107">The Extra's Academy Survival Guide Chapter 107 - Read Online</a>
      <a href="/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/106">Chapter 106</a>
      <a href="/privacy">Privacy Policy</a>
    </main>
    """

    let snapshot = HTMLChapterIndexParser.parse(
        html: html,
        baseURL: baseURL,
        seriesID: seriesID,
        checkedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    #expect(snapshot.seriesID == seriesID)
    #expect(snapshot.entries.map(\.chapterLabel) == ["106", "107"])
    #expect(snapshot.entries.map(\.chapterNumber) == [106, 107])
    #expect(snapshot.entries[1].sourceURL.absoluteString == "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/107")
    #expect(snapshot.latestChapterLabel == "107")
}

@Test func chapterIndexParserDeduplicatesSameChapterURL() throws {
    let seriesID = UUID(uuidString: "CC308F48-53EF-4C5F-96A2-694CF89F10F1")!
    let baseURL = try #require(URL(string: "https://example.com/series/moonlit-edge"))
    let html = """
    <a href="/series/moonlit-edge/chapter-12">Chapter 12</a>
    <a href="/series/moonlit-edge/chapter-12">Read Chapter 12 Online</a>
    <a href="/series/moonlit-edge/chapter-13">Chapter 13</a>
    """

    let snapshot = HTMLChapterIndexParser.parse(html: html, baseURL: baseURL, seriesID: seriesID)

    #expect(snapshot.entries.map(\.chapterLabel) == ["12", "13"])
}

@MainActor
@Test func persistentDependenciesExposeChapterIndexRefreshService() throws {
    let dependencies = try AppDependencies.persistent(inMemory: true, usesModelContextIO: false)

    #expect(dependencies.chapterIndexRefreshService != nil)
}

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
    )
    let fetcher = HTMLLatestChapterFetcher(
        httpClient: client,
        now: { Date(timeIntervalSince1970: 1_700_000_200) }
    )

    let snapshot = try await fetcher.latestChapterSnapshot(for: series)

    #expect(await client.requestedURLs == [canonicalURL])
    #expect(snapshot?.latestChapterLabel == "13")
    #expect(snapshot?.sourceURL == URL(string: "https://example.com/series/chapter-13")!)
}

@Test func htmlLatestChapterFetcherReturnsNilOnNetworkFailure() async throws {
    let series = LibrarySeriesSummary.updateCheckFixture(
        latestChapterLabel: "12",
        canonicalURL: URL(string: "https://example.com/series")!
    )
    let fetcher = HTMLLatestChapterFetcher(
        httpClient: RecordingHTTPDataLoader(result: .failure(URLError(.timedOut)))
    )

    let snapshot = try await fetcher.latestChapterSnapshot(for: series)

    #expect(snapshot == nil)
}

@Test func htmlLatestChapterFetcherReturnsNilForNonHTTPURL() async throws {
    let series = LibrarySeriesSummary.updateCheckFixture(
        latestChapterLabel: "12",
        canonicalURL: URL(string: "file:///tmp/series.html")!
    )
    let client = RecordingHTTPDataLoader(
        result: .success(HTTPDataResponse(data: Data(), statusCode: 200))
    )
    let fetcher = HTMLLatestChapterFetcher(httpClient: client)

    let snapshot = try await fetcher.latestChapterSnapshot(for: series)

    #expect(snapshot == nil)
    #expect(await client.requestedURLs.isEmpty)
}

@Test func htmlLatestChapterFetcherReturnsNilForInvalidHTTPResponse() async throws {
    let series = LibrarySeriesSummary.updateCheckFixture(
        latestChapterLabel: "12",
        canonicalURL: URL(string: "https://example.com/series")!
    )
    let fetcher = HTMLLatestChapterFetcher(
        httpClient: RecordingHTTPDataLoader(
            result: .success(HTTPDataResponse(data: Data(#"<a href="/series/chapter-13">Chapter 13</a>"#.utf8), statusCode: 500))
        )
    )

    let snapshot = try await fetcher.latestChapterSnapshot(for: series)

    #expect(snapshot == nil)
}

@Test func htmlSeriesMetadataParserExtractsOpenGraphCover() throws {
    let baseURL = try #require(URL(string: "https://example.com/series/past-life-returner"))
    let html = """
    <html>
      <head>
        <meta property="og:title" content="Past Life Returner" />
        <meta property="og:image" content="/covers/past-life-returner.jpg" />
      </head>
    </html>
    """

    let metadata = try #require(HTMLSeriesMetadataParser.parse(html: html, baseURL: baseURL))

    #expect(metadata.title == "Past Life Returner")
    #expect(metadata.coverImageURL?.absoluteString == "https://example.com/covers/past-life-returner.jpg")
}

@Test func htmlSeriesMetadataParserPrefersStructuredPortraitCoverOverSocialPreviewImage() throws {
    let baseURL = try #require(URL(string: "https://vortexscans.org/series/past-life-returner"))
    let html = """
    <html>
      <head>
        <meta property="og:title" content="Past Life Returner" />
        <meta property="og:image" content="https://vortexscans.org/api/og-image/series/past-life-returner/banner.webp" />
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@graph": [
            {
              "@type": "ImageObject",
              "@id": "https://storage.vortexscans.org/upload/cover.webp",
              "url": "https://storage.vortexscans.org/upload/cover.webp",
              "width": "160",
              "height": "231"
            },
            {
              "@type": "WebPage",
              "primaryImageOfPage": {
                "@id": "https://storage.vortexscans.org/upload/cover.webp"
              }
            }
          ]
        }
        </script>
      </head>
    </html>
    """

    let metadata = try #require(HTMLSeriesMetadataParser.parse(html: html, baseURL: baseURL))

    #expect(metadata.coverImageURL?.absoluteString == "https://storage.vortexscans.org/upload/cover.webp")
}

@Test func htmlSeriesMetadataParserExtractsAsuraStyleSeriesCoverImage() throws {
    let baseURL = try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5"))
    let html = """
    <html>
      <head>
        <meta property="og:title" content="The Extra’s Academy Survival Guide | Asura Scans" />
      </head>
      <body>
        <img alt="Asura Scans" src="/logo.webp" width="120" height="40" />
        <img alt="The Extra’s Academy Survival Guide" src="/cdn-cgi/image/width=400/uploads/cover.webp" width="400" height="600" />
        <h1>The Extra’s Academy Survival Guide</h1>
      </body>
    </html>
    """

    let metadata = try #require(HTMLSeriesMetadataParser.parse(html: html, baseURL: baseURL))

    #expect(metadata.title?.contains("The Extra’s Academy Survival Guide") == true)
    #expect(metadata.coverImageURL?.absoluteString == "https://asurascans.com/cdn-cgi/image/width=400/uploads/cover.webp")
}

@Test func htmlSeriesMetadataFetcherRequestsCanonicalSeriesURL() async throws {
    let seriesURL = try #require(URL(string: "https://example.com/series/past-life-returner"))
    let client = RecordingHTTPDataLoader(
        result: .success(HTTPDataResponse(
            data: Data("""
            <meta property="og:image" content="https://cdn.example.com/cover.jpg">
            """.utf8),
            statusCode: 200
        ))
    )
    let fetcher = HTMLSeriesMetadataFetcher(httpClient: client)

    let metadata = try await fetcher.metadata(for: seriesURL)

    #expect(await client.requestedURLs == [seriesURL])
    #expect(metadata?.coverImageURL?.absoluteString == "https://cdn.example.com/cover.jpg")
}

@Test func libraryUpdateRefreshChecksAllSavedSeries() async throws {
    let series = [
        LibrarySeriesSummary.updateCheckFixture(id: UUID(uuidString: "2A0FE80C-4790-47BD-94BD-900AF539B957")!, latestChapterLabel: "12"),
        LibrarySeriesSummary.updateCheckFixture(id: UUID(uuidString: "AB7460A8-9B98-44EC-BDAB-F8077BAEF62D")!, latestChapterLabel: "3")
    ]
    let checker = RecordingSeriesUpdateChecker(resultsBySeriesID: [
        series[0].id: SeriesUpdateCheckResult(
            seriesID: series[0].id,
            latestChapterLabel: "13",
            hasUnreadUpdates: true,
            checkedAt: Date(timeIntervalSince1970: 1_700_000_300),
            comparison: .newerAvailable
        ),
        series[1].id: SeriesUpdateCheckResult(
            seriesID: series[1].id,
            latestChapterLabel: "3",
            hasUnreadUpdates: false,
            checkedAt: Date(timeIntervalSince1970: 1_700_000_301),
            comparison: .same
        )
    ])
    let library = RecordingUpdateLibrary(series: series)
    let service = LibraryUpdateRefreshService(library: library, updateChecker: checker)

    let result = await service.refreshUpdates()

    #expect(await checker.requestedSeriesIDs == series.map(\.id))
    #expect(result.checkedCount == 2)
    #expect(result.updatedCount == 1)
    #expect(result.failedCount == 0)
}

@Test func libraryUpdateRefreshPersistsUpdateResults() async throws {
    let series = LibrarySeriesSummary.updateCheckFixture(latestChapterLabel: "12")
    let checkedAt = Date(timeIntervalSince1970: 1_700_000_300)
    let library = RecordingUpdateLibrary(series: [series])
    let service = LibraryUpdateRefreshService(
        library: library,
        updateChecker: RecordingSeriesUpdateChecker(resultsBySeriesID: [
            series.id: SeriesUpdateCheckResult(
                seriesID: series.id,
                latestChapterLabel: "13",
                hasUnreadUpdates: true,
                checkedAt: checkedAt,
                comparison: .newerAvailable
            )
        ])
    )

    _ = await service.refreshUpdates()

    #expect(await library.recordedUpdateResults == [
        RecordedUpdateResult(
            seriesID: series.id,
            latestChapterLabel: "13",
            hasUnreadUpdates: true,
            checkedAt: checkedAt
        )
    ])
}

@Test func libraryUpdateRefreshDoesNotClearExistingUpdateStateWhenFetchFails() async throws {
    let series = LibrarySeriesSummary.updateCheckFixture(latestChapterLabel: "12", hasUnreadUpdates: true)
    let library = RecordingUpdateLibrary(series: [series])
    let service = LibraryUpdateRefreshService(
        library: library,
        updateChecker: RecordingSeriesUpdateChecker(failingSeriesIDs: [series.id])
    )

    let result = await service.refreshUpdates()
    let snapshot = await library.librarySnapshot()

    #expect(result.checkedCount == 1)
    #expect(result.updatedCount == 0)
    #expect(result.failedCount == 1)
    #expect(await library.recordedUpdateResults.isEmpty)
    #expect(snapshot.series.first?.hasUnreadUpdates == true)
}

@Test func libraryUpdateRefreshLogsCheckedUpdatedAndFailedCounts() async throws {
    let series = LibrarySeriesSummary.updateCheckFixture(latestChapterLabel: "12")
    let logger = RecordingUpdateCacheDiagnosticsLogger()
    let service = LibraryUpdateRefreshService(
        library: RecordingUpdateLibrary(series: [series]),
        updateChecker: RecordingSeriesUpdateChecker(failingSeriesIDs: [series.id]),
        diagnosticsLogger: logger
    )

    _ = await service.refreshUpdates()

    #expect(await logger.events == [
        .updateRefreshCompleted(checkedCount: 1, updatedCount: 0, failedCount: 1)
    ])
}

@Test func chapterIndexRefreshServiceRecordsIndexAndUpdateState() async throws {
    let seriesID = UUID(uuidString: "A2EDB8E4-7F21-4608-9C8C-5DCFE4B35531")!
    let series = LibrarySeriesSummary.updateCheckFixture(id: seriesID, latestChapterLabel: "106")
    let library = RecordingChapterIndexLibrary(snapshot: LibrarySnapshot(series: [series]))
    let fetcher = StubChapterIndexFetcher()
    fetcher.snapshots[seriesID] = ChapterIndexSnapshot(
        seriesID: seriesID,
        entries: [
            ChapterIndexEntry(
                title: "Chapter 107",
                chapterLabel: "107",
                chapterNumber: 107,
                sourceURL: URL(string: "https://example.com/chapter-107")!
            )
        ],
        checkedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let service = SeriesChapterIndexRefreshService(library: library, indexLibrary: library, fetcher: fetcher)

    let outcome = await service.refreshChapterIndex(for: series)

    #expect(outcome.didRefresh)
    #expect(outcome.latestChapterLabel == "107")
    #expect(outcome.hasUnreadUpdates)
    #expect(library.recordedIndexes.first?.chapters.map(\.chapterLabel) == ["107"])
    #expect(library.updateResults.first?.latestChapterLabel == "107")
    #expect(library.updateResults.first?.hasUnreadUpdates == true)
}

@Test func chapterIndexRefreshServiceKeepsUnreadUpdateWhenLatestIndexedChapterIsStillUnread() async throws {
    let seriesID = UUID(uuidString: "F76C2254-6D63-4F00-879B-97F390615E21")!
    let chapter107ID = UUID(uuidString: "A99FA534-2A9F-41B1-A77D-74E987EF71BC")!
    let series = LibrarySeriesSummary.updateCheckFixture(
        id: seriesID,
        latestChapterLabel: "107",
        hasUnreadUpdates: true
    )
    let chapter107URL = URL(string: "https://example.com/chapter-107")!
    let library = RecordingChapterIndexLibrary(snapshot: LibrarySnapshot(series: [series]))
    library.details[seriesID] = SeriesDetailSnapshot(
        id: seriesID,
        title: "Moonlit Edge",
        status: "Reading",
        synopsis: "",
        sourceDomain: "example.com",
        coverImageURL: nil,
        isSaved: true,
        libraryState: .reading,
        progressPercent: 0.5,
        chaptersRead: 1,
        totalKnownChapters: 2,
        hasUnreadUpdates: true,
        chapters: [
            ChapterSummary(
                id: UUID(),
                title: "Chapter 106",
                chapterLabel: "106",
                chapterNumber: 106,
                sourceURL: URL(string: "https://example.com/chapter-106")!,
                readState: .read,
                isDownloaded: false,
                publishedAt: nil,
                lastReadAt: Date(timeIntervalSince1970: 1_700_000_000),
                isGeneratedPlaceholder: false,
                isOpenable: true
            ),
            ChapterSummary(
                id: chapter107ID,
                title: "Chapter 107",
                chapterLabel: "107",
                chapterNumber: 107,
                sourceURL: chapter107URL,
                readState: .unread,
                isDownloaded: false,
                publishedAt: nil,
                lastReadAt: nil,
                isGeneratedPlaceholder: false,
                isOpenable: true
            )
        ]
    )
    let fetcher = StubChapterIndexFetcher()
    fetcher.snapshots[seriesID] = ChapterIndexSnapshot(
        seriesID: seriesID,
        entries: [
            ChapterIndexEntry(
                title: "Chapter 107",
                chapterLabel: "107",
                chapterNumber: 107,
                sourceURL: chapter107URL
            )
        ]
    )
    let service = SeriesChapterIndexRefreshService(library: library, indexLibrary: library, fetcher: fetcher)

    let outcome = await service.refreshChapterIndex(for: series)

    #expect(outcome.didRefresh)
    #expect(outcome.latestChapterLabel == "107")
    #expect(outcome.hasUnreadUpdates)
    #expect(library.updateResults.last?.hasUnreadUpdates == true)
}

@Test func libraryUpdateRefreshUsesChapterIndexRefreshWhenAvailable() async throws {
    let seriesID = UUID(uuidString: "41B54FDE-23F9-4D68-8B4B-7A1E05C2AD30")!
    let series = LibrarySeriesSummary.updateCheckFixture(id: seriesID, latestChapterLabel: "106")
    let library = RecordingChapterIndexLibrary(snapshot: LibrarySnapshot(series: [series]))
    let fetcher = StubChapterIndexFetcher()
    fetcher.snapshots[seriesID] = ChapterIndexSnapshot(
        seriesID: seriesID,
        entries: [
            ChapterIndexEntry(
                title: "Chapter 107",
                chapterLabel: "107",
                chapterNumber: 107,
                sourceURL: URL(string: "https://example.com/chapter-107")!
            )
        ]
    )
    let indexRefresh = SeriesChapterIndexRefreshService(library: library, indexLibrary: library, fetcher: fetcher)
    let refresh = LibraryUpdateRefreshService(
        library: library,
        updateChecker: StaticSeriesUpdateChecker(result: .same),
        chapterIndexRefreshService: indexRefresh
    )

    let result = await refresh.refreshUpdates()

    #expect(result.checkedCount == 1)
    #expect(result.updatedCount == 1)
    #expect(result.failedCount == 0)
    #expect(fetcher.requestedSeriesIDs == [seriesID])
}

@Test func libraryUpdateRefreshFallsBackWhenChapterIndexRefreshDoesNotRefresh() async throws {
    let seriesID = UUID(uuidString: "AF4C0E84-228B-4D06-8EF3-439284D35291")!
    let series = LibrarySeriesSummary.updateCheckFixture(id: seriesID, latestChapterLabel: "106")
    let library = RecordingChapterIndexLibrary(snapshot: LibrarySnapshot(series: [series]))
    let fetcher = StubChapterIndexFetcher()
    let checker = RecordingSeriesUpdateChecker(resultsBySeriesID: [
        seriesID: SeriesUpdateCheckResult(
            seriesID: seriesID,
            latestChapterLabel: "107",
            hasUnreadUpdates: true,
            checkedAt: Date(timeIntervalSince1970: 1_700_000_302),
            comparison: .newerAvailable
        )
    ])
    let indexRefresh = SeriesChapterIndexRefreshService(library: library, indexLibrary: library, fetcher: fetcher)
    let refresh = LibraryUpdateRefreshService(
        library: library,
        updateChecker: checker,
        chapterIndexRefreshService: indexRefresh
    )

    let result = await refresh.refreshUpdates()

    #expect(result.checkedCount == 1)
    #expect(result.updatedCount == 1)
    #expect(result.failedCount == 0)
    #expect(fetcher.requestedSeriesIDs == [seriesID])
    #expect(await checker.requestedSeriesIDs == [seriesID])
    #expect(library.updateResults.last?.latestChapterLabel == "107")
    #expect(library.updateResults.last?.hasUnreadUpdates == true)
}

@Test func htmlLatestChapterFetcherLogsParserPathWithoutFullURL() async throws {
    let canonicalURL = URL(string: "https://example.com/series?token=secret")!
    let series = LibrarySeriesSummary.updateCheckFixture(latestChapterLabel: "12", canonicalURL: canonicalURL)
    let logger = RecordingUpdateCacheDiagnosticsLogger()
    let fetcher = HTMLLatestChapterFetcher(
        httpClient: RecordingHTTPDataLoader(
            result: .success(
                HTTPDataResponse(
                    data: Data(#"<a href="/series/chapter-13">Chapter 13</a>"#.utf8),
                    statusCode: 200
                )
            )
        ),
        diagnosticsLogger: logger
    )

    _ = try await fetcher.latestChapterSnapshot(for: series)

    let events = await logger.events
    #expect(events == [
        .latestChapterParseCompleted(host: "example.com", parser: "generic-html-anchor", found: true)
    ])
    #expect(!String(describing: events).contains("token=secret"))
}

private actor RecordingLatestChapterFetcher: SeriesLatestChapterFetching {
    private let snapshot: SeriesLatestChapterSnapshot?
    private(set) var requestedSeriesIDs: [UUID] = []

    init(snapshot: SeriesLatestChapterSnapshot?) {
        self.snapshot = snapshot
    }

    func latestChapterSnapshot(for series: LibrarySeriesSummary) async throws -> SeriesLatestChapterSnapshot? {
        requestedSeriesIDs.append(series.id)
        return snapshot
    }
}

private actor RecordingUpdateCacheDiagnosticsLogger: UpdateCacheDiagnosticsLogging {
    private(set) var events: [UpdateCacheDiagnosticEvent] = []

    func log(_ event: UpdateCacheDiagnosticEvent) async {
        events.append(event)
    }
}

private struct RecordedUpdateResult: Equatable, Sendable {
    var seriesID: UUID
    var latestChapterLabel: String?
    var hasUnreadUpdates: Bool
    var checkedAt: Date
}

private actor RecordingSeriesUpdateChecker: SeriesUpdateChecking {
    private let resultsBySeriesID: [UUID: SeriesUpdateCheckResult]
    private let failingSeriesIDs: Set<UUID>
    private(set) var requestedSeriesIDs: [UUID] = []

    init(
        resultsBySeriesID: [UUID: SeriesUpdateCheckResult] = [:],
        failingSeriesIDs: Set<UUID> = []
    ) {
        self.resultsBySeriesID = resultsBySeriesID
        self.failingSeriesIDs = failingSeriesIDs
    }

    func checkForUpdates(series: LibrarySeriesSummary) async throws -> SeriesUpdateCheckResult {
        requestedSeriesIDs.append(series.id)
        if failingSeriesIDs.contains(series.id) {
            throw URLError(.cannotLoadFromNetwork)
        }
        return resultsBySeriesID[series.id] ?? SeriesUpdateCheckResult(
            seriesID: series.id,
            latestChapterLabel: series.latestChapterLabel,
            hasUnreadUpdates: false,
            checkedAt: Date(timeIntervalSince1970: 1_700_000_000),
            comparison: .same
        )
    }
}

private struct StaticSeriesUpdateChecker: SeriesUpdateChecking {
    var result: ChapterUpdateComparisonResult

    func checkForUpdates(series: LibrarySeriesSummary) async throws -> SeriesUpdateCheckResult {
        SeriesUpdateCheckResult(
            seriesID: series.id,
            latestChapterLabel: series.latestChapterLabel,
            hasUnreadUpdates: result != .same,
            checkedAt: Date(timeIntervalSince1970: 1_700_000_000),
            comparison: result
        )
    }
}

private final class StubChapterIndexFetcher: SeriesChapterIndexFetching, @unchecked Sendable {
    var snapshots: [UUID: ChapterIndexSnapshot] = [:]
    var requestedSeriesIDs: [UUID] = []

    func chapterIndexSnapshot(for series: LibrarySeriesSummary) async throws -> ChapterIndexSnapshot? {
        requestedSeriesIDs.append(series.id)
        return snapshots[series.id]
    }
}

private final class RecordingChapterIndexLibrary: LibraryLifecycleManaging, LibraryChapterIndexManaging, @unchecked Sendable {
    var snapshot: LibrarySnapshot
    var details: [UUID: SeriesDetailSnapshot] = [:]
    var recordedIndexes: [(seriesID: UUID, chapters: [ChapterIndexEntry])] = []
    var updateResults: [(seriesID: UUID, latestChapterLabel: String?, hasUnreadUpdates: Bool)] = []

    init(snapshot: LibrarySnapshot) {
        self.snapshot = snapshot
    }

    func homeSnapshot() async -> HomeSnapshot {
        HomeSnapshot(continueReading: [], recentlyUpdated: [], library: [])
    }

    func librarySnapshot() async -> LibrarySnapshot {
        snapshot
    }

    func librarySearchItems() async -> [LibrarySearchItem] {
        snapshot.series.map(LibrarySearchItem.init(summary:))
    }

    func seriesDetail(for seriesID: UUID) async -> SeriesDetailSnapshot? {
        details[seriesID]
    }

    func addToLibrary(_ input: LibrarySeriesInput, context: LibraryAddContext) async throws {}

    func removeFromLibrary(seriesID: UUID) async throws {}

    func updateLibraryState(_ state: LibraryCollectionState, for seriesID: UUID) async throws {}

    func recordUpdateCheckResult(
        seriesID: UUID,
        latestChapterLabel: String?,
        hasUnreadUpdates: Bool,
        checkedAt: Date
    ) async throws {
        updateResults.append((seriesID, latestChapterLabel, hasUnreadUpdates))
    }

    func recordReadingProgress(_ progress: ReaderProgress, forChapterID chapterID: UUID, at date: Date) async throws {}

    func continueReadingTarget(for seriesID: UUID) async -> ContinueReadingTarget? { nil }

    func readerSession(forChapterID chapterID: UUID) async -> MockReaderSession? { nil }

    func readerSession(forSourceURL sourceURL: URL) async -> MockReaderSession? { nil }

    func isSaved(canonicalURL: URL) async -> Bool { false }

    func recordAvailableChapters(
        _ chapters: [ChapterIndexEntry],
        for seriesID: UUID,
        indexedAt: Date
    ) async throws {
        recordedIndexes.append((seriesID, chapters))
    }
}

private actor RecordingUpdateLibrary: LibraryLifecycleManaging {
    private var snapshot: LibrarySnapshot
    private(set) var recordedUpdateResults: [RecordedUpdateResult] = []

    init(series: [LibrarySeriesSummary]) {
        self.snapshot = LibrarySnapshot(series: series)
    }

    func homeSnapshot() async -> HomeSnapshot {
        HomeSnapshot(continueReading: [], recentlyUpdated: [], library: [])
    }

    func librarySnapshot() async -> LibrarySnapshot {
        snapshot
    }

    func librarySearchItems() async -> [LibrarySearchItem] {
        snapshot.series.map(LibrarySearchItem.init(summary:))
    }

    func seriesDetail(for seriesID: UUID) async -> SeriesDetailSnapshot? {
        nil
    }

    func addToLibrary(_ input: LibrarySeriesInput, context: LibraryAddContext) async throws {}

    func removeFromLibrary(seriesID: UUID) async throws {}

    func updateLibraryState(_ state: LibraryCollectionState, for seriesID: UUID) async throws {}

    func recordUpdateCheckResult(
        seriesID: UUID,
        latestChapterLabel: String?,
        hasUnreadUpdates: Bool,
        checkedAt: Date
    ) async throws {
        recordedUpdateResults.append(
            RecordedUpdateResult(
                seriesID: seriesID,
                latestChapterLabel: latestChapterLabel,
                hasUnreadUpdates: hasUnreadUpdates,
                checkedAt: checkedAt
            )
        )
        snapshot.series = snapshot.series.map { series in
            guard series.id == seriesID else { return series }
            var updated = series
            updated.latestChapterLabel = latestChapterLabel
            updated.hasUnreadUpdates = hasUnreadUpdates
            return updated
        }
    }

    func recordReadingProgress(_ progress: ReaderProgress, forChapterID chapterID: UUID, at date: Date) async throws {}

    func continueReadingTarget(for seriesID: UUID) async -> ContinueReadingTarget? {
        nil
    }

    func readerSession(forChapterID chapterID: UUID) async -> MockReaderSession? {
        nil
    }

    func readerSession(forSourceURL sourceURL: URL) async -> MockReaderSession? {
        nil
    }

    func isSaved(canonicalURL: URL) async -> Bool {
        false
    }
}

private actor RecordingHTTPDataLoader: HTTPDataLoading {
    private let result: Result<HTTPDataResponse, Error>
    private(set) var requestedURLs: [URL] = []

    init(result: Result<HTTPDataResponse, Error>) {
        self.result = result
    }

    func data(from url: URL) async throws -> HTTPDataResponse {
        requestedURLs.append(url)
        return try result.get()
    }
}

private extension LibrarySeriesSummary {
    static func updateCheckFixture(
        id: UUID = UUID(uuidString: "2A0FE80C-4790-47BD-94BD-900AF539B957")!,
        latestChapterLabel: String?,
        canonicalURL: URL? = nil,
        hasUnreadUpdates: Bool = false
    ) -> LibrarySeriesSummary {
        LibrarySeriesSummary(
            id: id,
            title: "Update Fixture",
            sourceDomain: "example.com",
            canonicalURL: canonicalURL,
            coverImageURL: nil,
            progressPercent: 0.4,
            chaptersRead: 12,
            totalKnownChapters: 13,
            lastReadAt: nil,
            libraryState: .reading,
            hasUnreadUpdates: hasUnreadUpdates,
            isCompleted: false,
            latestChapterLabel: latestChapterLabel,
            currentChapterLabel: "12"
        )
    }
}
