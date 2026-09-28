import Foundation
import Testing
@testable import ToonEdgeAppCore

@Test func libraryPhaseDoesNotExposeEmptyBeforeInitialLoadCompletes() {
    #expect(LibraryContentPhase(hasLoadedSnapshot: false, visibleCount: 0) == .loading)
    #expect(LibraryContentPhase(hasLoadedSnapshot: true, visibleCount: 0) == .empty)
    #expect(LibraryContentPhase(hasLoadedSnapshot: true, visibleCount: 7) == .content)
}

@Test func librarySnapshotFiltersSeriesBySegment() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let reading = LibrarySeriesSummary.mock(
        title: "Reading Title",
        libraryState: .reading,
        progressPercent: 0.42,
        lastReadAt: now.addingTimeInterval(-60)
    )
    let planned = LibrarySeriesSummary.mock(
        title: "Planned Title",
        libraryState: .planned,
        progressPercent: 0,
        lastReadAt: nil
    )
    let updated = LibrarySeriesSummary.mock(
        title: "Updated Title",
        libraryState: .reading,
        progressPercent: 0.8,
        hasUnreadUpdates: true,
        lastReadAt: now.addingTimeInterval(-3_600)
    )
    let dropped = LibrarySeriesSummary.mock(
        title: "Dropped Title",
        libraryState: .dropped,
        progressPercent: 0.1,
        lastReadAt: nil
    )
    let completed = LibrarySeriesSummary.mock(
        title: "Completed Title",
        libraryState: .completed,
        progressPercent: 1,
        lastReadAt: nil
    )
    let snapshot = LibrarySnapshot(series: [planned, reading, updated, dropped, completed])

    #expect(snapshot.series(for: .reading).map(\.title) == ["Reading Title", "Updated Title"])
    #expect(snapshot.series(for: .planned).map(\.title) == ["Planned Title"])
    #expect(snapshot.series(for: .dropped).map(\.title) == ["Dropped Title"])
    #expect(snapshot.series(for: .completed).map(\.title) == ["Completed Title"])
    #expect(snapshot.series(for: .recent).map(\.title) == ["Reading Title", "Updated Title"])
}

@Test func librarySegmentsExposeRecentAndAllCollectionGroups() {
    #expect(LibrarySegment.allCases == [.recent, .reading, .planned, .dropped, .completed])
    #expect(LibrarySegment.dropped.title == "Dropped")
    #expect(LibrarySegment.completed.title == "Completed")
    #expect(LibraryCollectionState.decoded(persistedRawValue: "archived") == .dropped)
    #expect(LibraryCollectionState.decoded(persistedRawValue: "unknown") == .planned)
}

@Test func seriesDetailPrimaryActionContinuesInProgressChapter() {
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(chapterLabel: "141", readState: .read),
            ChapterSummary.mock(chapterLabel: "142", readState: .inProgress(progressPercent: 0.35)),
            ChapterSummary.mock(chapterLabel: "143", readState: .unread)
        ]
    )

    #expect(detail.primaryActionTitle == "Continue Chapter 142")
    #expect(detail.primaryChapter?.chapterLabel == "142")
}

@Test func libraryHeaderLayoutUsesNavigationTitleWithoutToolbarRefresh() {
    let refreshable = LibraryHeaderLayout(hasUpdateRefreshService: true)
    let localOnly = LibraryHeaderLayout(hasUpdateRefreshService: false)

    #expect(refreshable.navigationTitle == "Library")
    #expect(refreshable.contentTitle == nil)
    #expect(!refreshable.toolbarRefreshIsAvailable)
    #expect(!localOnly.toolbarRefreshIsAvailable)
}

@Test func libraryCollectionControlsKeepCountRefreshAndViewModesInline() {
    let controls = LibraryCollectionControlsLayout(
        visibleSeries: [
            LibrarySeriesSummary.mock(title: "A"),
            LibrarySeriesSummary.mock(title: "B"),
            LibrarySeriesSummary.mock(title: "C"),
            LibrarySeriesSummary.mock(title: "D")
        ],
        hasUpdateRefreshService: true,
        isRefreshing: false
    )

    #expect(controls.countText == "4 titles")
    #expect(controls.refreshButtonIsVisible)
    #expect(controls.refreshSystemImage == "arrow.clockwise")
    #expect(LibraryViewMode.allCases == [.comfortable, .compact, .list])
    #expect(!controls.usesLargeSummaryCard)
}

@Test func libraryCollectionControlsExposeCountAndRefreshOnlyWhenServiceExists() {
    let series = [
        LibrarySeriesSummary.mock(title: "A"),
        LibrarySeriesSummary.mock(title: "B")
    ]

    let refreshable = LibraryCollectionControlsLayout(
        visibleSeries: series,
        hasUpdateRefreshService: true,
        isRefreshing: false
    )
    let localOnly = LibraryCollectionControlsLayout(
        visibleSeries: series,
        hasUpdateRefreshService: false,
        isRefreshing: false
    )
    let singular = LibraryCollectionControlsLayout(
        visibleSeries: [LibrarySeriesSummary.mock(title: "Only")],
        hasUpdateRefreshService: true,
        isRefreshing: false
    )

    #expect(refreshable.countText == "2 titles")
    #expect(singular.countText == "1 title")
    #expect(refreshable.refreshButtonIsVisible)
    #expect(!localOnly.refreshButtonIsVisible)
    #expect(!refreshable.usesLargeSummaryCard)
}

@Test func libraryCollectionControlsUseRefreshIconStateWithoutUpdateSummaryCopy() {
    let series = [
        LibrarySeriesSummary.mock(title: "A", hasUnreadUpdates: true),
        LibrarySeriesSummary.mock(title: "B", hasUnreadUpdates: false),
        LibrarySeriesSummary.mock(title: "C", hasUnreadUpdates: true)
    ]

    let idle = LibraryCollectionControlsLayout(
        visibleSeries: series,
        hasUpdateRefreshService: true,
        isRefreshing: false
    )
    let refreshing = LibraryCollectionControlsLayout(
        visibleSeries: series,
        hasUpdateRefreshService: true,
        isRefreshing: true
    )

    #expect(idle.countText == "3 titles")
    #expect(idle.refreshSystemImage == "arrow.clockwise")
    #expect(refreshing.refreshSystemImage == "hourglass")
    #expect(idle.refreshAccessibilityLabel == "Check for new chapters")
}

@Test func libraryRefreshFeedbackLayoutIsDismissibleAndAutoExpires() {
    let layout = LibraryRefreshFeedbackLayout(result: .init(checkedCount: 2, updatedCount: 1, failedCount: 0))

    #expect(layout.title == "Updates found")
    #expect(layout.message == "2 checked, 1 update")
    #expect(layout.presentationStyle == .floatingOverlay)
    #expect(layout.overlayAlignment == .bottomTrailing)
    #expect(layout.maximumWidth == 280)
    #expect(layout.contentSize == .compact)
    #expect(layout.accentColorRole == .success)
    #expect(!layout.reservesContentSpace)
    #expect(layout.dismissAccessibilityLabel == "Dismiss update refresh")
    #expect(layout.autoDismissDelay == 5)
}

@Test func libraryContentLayoutKeepsRefreshFeedbackOutOfFlow() {
    let layout = LibraryContentLayout(refreshFeedback: LibraryRefreshFeedbackLayout(result: .init(checkedCount: 2, updatedCount: 1, failedCount: 0)))

    #expect(layout.refreshFeedbackIsOverlay)
    #expect(layout.contentStartsWithSegmentedControl)
}

@Test func libraryEmptyStateUsesCenteredNothingSavedModel() {
    let visible = LibraryEmptyStateLayout(hasLoadedSnapshot: true, visibleSeries: [])
    let loading = LibraryEmptyStateLayout(hasLoadedSnapshot: false, visibleSeries: [])
    let populated = LibraryEmptyStateLayout(hasLoadedSnapshot: true, visibleSeries: [LibrarySeriesSummary.mock()])

    #expect(visible.isVisible)
    #expect(visible.message == "Nothing saved")
    #expect(visible.imageName == "sleepy transparent")
    #expect(visible.imageURL?.lastPathComponent == "sleepy transparent.png")
    #expect(!loading.isVisible)
    #expect(!populated.isVisible)
}

@Test func libraryDistinguishesEmptyCollectionFromEmptyFilter() {
    #expect(LibraryEmptyReason(totalCount: 0, visibleCount: 0) == .collection)
    #expect(LibraryEmptyReason(totalCount: 4, visibleCount: 0) == .filter)
}

@Test func accessibilityLayoutDoesNotOverwriteSavedDensity() {
    let policy = LibraryDensityPresentation(saved: .compact, accessibilityText: true)

    #expect(policy.savedPreference == .compact)
    #expect(policy.renderedMode == .list)
}

@Test func sleepyLibraryEmptyStateMascotImageIsBundled() throws {
    let imageURL = try #require(ToonEdgeAppCoreResources.urlForImage(named: "sleepy transparent", extension: "png"))

    #expect(imageURL.lastPathComponent == "sleepy transparent.png")
}

@MainActor
@Test func coverArtworkStartupPolicyUsesCachedDataImmediately() {
    let url = URL(string: "https://example.com/cover.jpg")!
    let cache = CoverArtworkMemoryCache()
    let expectedData = Data([0x01, 0x02, 0x03, 0x04])
    cache.store(expectedData, for: url)

    #expect(CoverArtworkStartupPolicy.initialData(url: url, cache: cache) == expectedData)
}

@Test func seriesDetailPrimaryActionUsesNumericChapterLabelsFromNoisySourceText() {
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(
                title: "The Extra’s Academy Survival Guide Chapter 102 - Read Online | Asura Scans",
                chapterLabel: "Scans",
                chapterNumber: nil,
                readState: .inProgress(progressPercent: 0.35)
            ),
            ChapterSummary.mock(
                title: "Chapter 103",
                chapterLabel: "Chapter Scans",
                chapterNumber: 103,
                readState: .unread
            )
        ]
    )

    #expect(detail.primaryActionTitle == "Continue Chapter 102")
}

@Test func seriesDetailPrimaryActionPrefersNextAfterLatestCompletedOverOlderUnfinishedChapter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(
                chapterLabel: "103",
                chapterNumber: 103,
                readState: .read,
                lastReadAt: now.addingTimeInterval(-30)
            ),
            ChapterSummary.mock(
                chapterLabel: "105",
                chapterNumber: 105,
                readState: .read,
                lastReadAt: now
            ),
            ChapterSummary.mock(
                chapterLabel: "104",
                chapterNumber: 104,
                readState: .read,
                lastReadAt: now.addingTimeInterval(-10)
            ),
            ChapterSummary.mock(
                title: "The Extra’s Academy Survival Guide Chapter 102 - Read Online | Asura Scans",
                chapterLabel: "Scans",
                chapterNumber: nil,
                readState: .inProgress(progressPercent: 0.0),
                lastReadAt: now.addingTimeInterval(-60)
            ),
            ChapterSummary.mock(
                chapterLabel: "106",
                chapterNumber: 106,
                readState: .unread
            )
        ]
    )

    #expect(detail.primaryActionTitle == "Start Chapter 106")
    #expect(detail.primaryChapter?.chapterLabel == "106")
}

@Test func seriesDetailPrimaryActionContinuesForwardInProgressChapterAfterLatestCompletedChapter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(
                chapterLabel: "103",
                chapterNumber: 103,
                readState: .read,
                lastReadAt: now.addingTimeInterval(-30)
            ),
            ChapterSummary.mock(
                chapterLabel: "105",
                chapterNumber: 105,
                readState: .read,
                lastReadAt: now
            ),
            ChapterSummary.mock(
                chapterLabel: "106",
                chapterNumber: 106,
                readState: .inProgress(progressPercent: 0.25),
                lastReadAt: now.addingTimeInterval(-10)
            )
        ]
    )

    #expect(detail.primaryActionTitle == "Continue Chapter 106")
    #expect(detail.primaryChapter?.chapterLabel == "106")
}

@Test func seriesDetailPrimaryActionDoesNotReturnToOlderInProgressAfterLatestKnownChapterIsRead() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(
                title: "The Extra’s Academy Survival Guide Chapter 102 - Read Online | Asura Scans",
                chapterLabel: "Scans",
                chapterNumber: nil,
                readState: .inProgress(progressPercent: 0.0),
                lastReadAt: now.addingTimeInterval(-240)
            ),
            ChapterSummary.mock(
                chapterLabel: "103",
                chapterNumber: 103,
                readState: .read,
                lastReadAt: now.addingTimeInterval(-180)
            ),
            ChapterSummary.mock(
                chapterLabel: "104",
                chapterNumber: 104,
                readState: .read,
                lastReadAt: now.addingTimeInterval(-120)
            ),
            ChapterSummary.mock(
                chapterLabel: "105",
                chapterNumber: 105,
                readState: .read,
                lastReadAt: now.addingTimeInterval(-60)
            ),
            ChapterSummary.mock(
                chapterLabel: "106",
                chapterNumber: 106,
                readState: .read,
                lastReadAt: now
            )
        ]
    )

    #expect(detail.primaryActionTitle == "All Chapters Read")
    #expect(detail.primaryChapter == nil)
}

@Test func seriesDetailHeaderLayoutDoesNotExposeReaderOriginCopy() {
    let detail = SeriesDetailSnapshot.mock(
        synopsis: "Saved from Reader Mode.",
        chapters: [ChapterSummary.mock(chapterLabel: "102")]
    )

    let layout = SeriesDetailHeaderLayout(snapshot: detail)

    #expect(layout.title == "Moonlit Edge")
    #expect(layout.synopsisText == nil)
    #expect(!layout.metadata.contains("Saved from Reader Mode"))
}

@Test func hydratedSeriesDetailLayoutKeepsHeaderFixedAndChaptersScrollable() {
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(chapterLabel: "100", readState: .read),
            ChapterSummary.mock(chapterLabel: "101", readState: .unread)
        ]
    )

    let layout = SeriesDetailPageLayout(detail: detail, seedSummary: nil, hasLoaded: true)

    #expect(layout.stateKind == .hydrated)
    #expect(layout.keepsHeaderFixed)
    #expect(layout.scrollsChaptersIndependently)
    #expect(layout.keepsPrimaryActionVisible)
}

@Test func seededSeriesDetailLayoutKeepsSeedHeaderVisibleWithoutChapterScroller() {
    let summary = LibrarySeriesSummary.mock(title: "Past Life Returner")

    let layout = SeriesDetailPageLayout(detail: nil, seedSummary: summary, hasLoaded: false)

    #expect(layout.stateKind == .seeded)
    #expect(layout.keepsHeaderFixed)
    #expect(!layout.scrollsChaptersIndependently)
    #expect(!layout.keepsPrimaryActionVisible)
}

@Test func nonHydratedSeriesDetailStatesDoNotCreateEmptyChapterScroller() {
    let loading = SeriesDetailPageLayout(detail: nil, seedSummary: nil, hasLoaded: false)
    let unavailable = SeriesDetailPageLayout(detail: nil, seedSummary: nil, hasLoaded: true)

    #expect(loading.stateKind == .loading)
    #expect(!loading.scrollsChaptersIndependently)
    #expect(unavailable.stateKind == .unavailable)
    #expect(!unavailable.scrollsChaptersIndependently)
}

@Test func librarySeriesDetailRouteIdentityUsesSeriesIDAndCarriesOptionalSeed() {
    let seriesID = UUID(uuidString: "C8D607B4-91EC-4D18-B28B-0626E9A8C748")!
    let firstSeed = LibrarySeriesSummary.mock(
        id: seriesID,
        title: "The Extra's Academy Survival Guide",
        sourceDomain: "asurascans.com",
        currentChapterLabel: "101"
    )
    let refreshedSeed = LibrarySeriesSummary.mock(
        id: seriesID,
        title: "The Extra's Academy Survival Guide | Asura Scans",
        sourceDomain: "asurascans.com",
        currentChapterLabel: "102"
    )

    let firstRoute = LibrarySeriesDetailRoute(seriesID: seriesID, seedSummary: firstSeed)
    let refreshedRoute = LibrarySeriesDetailRoute(seriesID: seriesID, seedSummary: refreshedSeed)
    let unseededRoute = LibrarySeriesDetailRoute(seriesID: seriesID, seedSummary: nil)

    #expect(firstRoute == refreshedRoute)
    #expect(firstRoute == unseededRoute)
    #expect(firstRoute.seedSummary?.title == "The Extra's Academy Survival Guide")
}

@Test func seriesDetailBrowserFallbackCarriesLibraryReaderLaunchOrigin() throws {
    let seriesID = UUID()
    let chapterURL = try #require(URL(string: "https://asurascans.com/comics/extras/chapter/107"))
    let chapter = ChapterSummary(
        title: "The Extra's Academy Survival Guide Chapter 107",
        chapterLabel: "107",
        chapterNumber: 107,
        sourceURL: chapterURL,
        readState: .unread,
        isDownloaded: false,
        publishedAt: nil
    )

    let route = SeriesDetailChapterOpenRoute(chapter: chapter, seriesID: seriesID)

    #expect(route.browserStartPoint == .url(chapterURL.absoluteString))
    #expect(route.browserReaderLaunchOrigin == .library(seriesID: seriesID))
}

@Test func librarySeriesDetailRouteUsesVisibleSeriesAsSeed() {
    let summary = LibrarySeriesSummary.mock(
        title: "The Extra's Academy Survival Guide",
        sourceDomain: "asurascans.com"
    )
    let route = LibrarySeriesDetailRoute(summary: summary)

    #expect(route.seriesID == summary.id)
    #expect(route.seedSummary == summary)
}

@Test func librarySummaryResumeTargetExposesConcreteStartAction() {
    let chapter = ChapterSummary.mock(
        chapterLabel: "101",
        chapterNumber: 101,
        readState: .unread,
        sourceURL: URL(string: "https://example.com/chapter-101")!
    )
    let target = LibraryResumeTarget(chapter: chapter)
    let summary = LibrarySeriesSummary.mock(
        title: "Moonlit Edge",
        currentChapterLabel: "100",
        latestChapterLabel: "200",
        resumeTarget: target
    )

    #expect(summary.resumeTarget?.chapter.id == chapter.id)
    #expect(summary.resumeTarget?.actionTitle == "Start Chapter 101")
    #expect(summary.resumeTarget?.chapter.sourceURL.absoluteString == "https://example.com/chapter-101")
}

@Test func librarySummaryResumeTargetExposesConcreteContinueAction() {
    let chapter = ChapterSummary.mock(
        chapterLabel: "100",
        chapterNumber: 100,
        readState: .inProgress(progressPercent: 0.42),
        sourceURL: URL(string: "https://example.com/chapter-100")!
    )
    let target = LibraryResumeTarget(chapter: chapter)

    #expect(target.actionTitle == "Continue Chapter 100")
}

@Test func seriesDetailSeedShellShowsLibrarySummaryWithoutContinueAction() {
    let summary = LibrarySeriesSummary.mock(
        title: "Past Life Returner",
        sourceDomain: "vortexscans.org",
        libraryState: .reading,
        progressPercent: 0.48,
        chaptersRead: 101,
        totalKnownChapters: 200,
        hasUnreadUpdates: false,
        currentChapterLabel: "101"
    )

    let layout = SeriesDetailSeedShellLayout(summary: summary)

    #expect(layout.title == "Past Life Returner")
    #expect(layout.metadata == "vortexscans.org • 101/200 chapters")
    #expect(layout.status == "Reading")
    #expect(!layout.hasUnreadUpdates)
    #expect(!layout.showsLoadingBanner)
    #expect(!layout.exposesContinueAction)
    #expect(layout.primaryChapter == nil)
    #expect(layout.primaryActionTitle == nil)
}

@Test func seriesDetailSeedShellPreservesKnownLibraryCoverURL() {
    let coverURL = URL(string: "https://asurascans.com/covers/extras-academy.jpg")!
    let summary = LibrarySeriesSummary.mock(
        title: "The Extra's Academy Survival Guide | Asura Scans",
        sourceDomain: "asurascans.com",
        coverImageURL: coverURL,
        chaptersRead: 4,
        totalKnownChapters: 122
    )

    let layout = SeriesDetailSeedShellLayout(summary: summary)
    let cover = SeriesDetailCoverLayout(coverImageURL: layout.coverImageURL)

    #expect(layout.coverImageURL == coverURL)
    #expect(cover.coverImageURL == coverURL)
    #expect(!cover.usesPlaceholder)
}

@Test func seriesDetailSeedShellExposesContinueWhenSummaryHasConcreteResumeTarget() {
    let chapter = ChapterSummary.mock(
        chapterLabel: "101",
        chapterNumber: 101,
        readState: .unread,
        sourceURL: URL(string: "https://example.com/chapter-101")!
    )
    let summary = LibrarySeriesSummary.mock(
        title: "Moonlit Edge",
        sourceDomain: "example.com",
        resumeTarget: LibraryResumeTarget(chapter: chapter)
    )

    let layout = SeriesDetailSeedShellLayout(summary: summary)

    #expect(layout.exposesContinueAction)
    #expect(layout.primaryChapter == chapter)
    #expect(layout.primaryActionTitle == "Start Chapter 101")
}

@Test func seededSeriesDetailUsesHydratedDetailForContinueAction() {
    let summary = LibrarySeriesSummary.mock(
        title: "Past Life Returner",
        sourceDomain: "vortexscans.org",
        chaptersRead: 101,
        totalKnownChapters: 200,
        currentChapterLabel: "101"
    )
    let chapter101 = ChapterSummary.mock(chapterLabel: "101", chapterNumber: 101, readState: .read)
    let chapter102 = ChapterSummary.mock(chapterLabel: "102", chapterNumber: 102, readState: .unread)
    let detail = SeriesDetailSnapshot.mock(chapters: [chapter101, chapter102])

    let seedLayout = SeriesDetailSeedShellLayout(summary: summary)
    let hydratedLayout = SeriesDetailHeaderLayout(snapshot: detail)

    #expect(!seedLayout.exposesContinueAction)
    #expect(hydratedLayout.primaryActionTitle == "Start Chapter 102")
}

@Test func hydratedSeriesDetailKeepsKnownCoverURLFromStoredDetail() {
    let coverURL = URL(string: "https://asurascans.com/covers/extras-academy.jpg")!
    let detail = SeriesDetailSnapshot.mock(
        title: "The Extra's Academy Survival Guide | Asura Scans",
        coverImageURL: coverURL,
        chapters: [
            ChapterSummary.mock(chapterLabel: "101", readState: .read),
            ChapterSummary.mock(chapterLabel: "102", readState: .unread)
        ]
    )

    let cover = SeriesDetailCoverLayout(coverImageURL: detail.coverImageURL)

    #expect(cover.coverImageURL == coverURL)
    #expect(!cover.usesPlaceholder)
}

@Test func seriesDetailRefreshBehaviorStartsOnlyAfterLocalDetailExists() {
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(chapterLabel: "106", readState: .read),
            ChapterSummary.mock(chapterLabel: "107", readState: .unread)
        ]
    )

    #expect(!SeriesDetailRefreshBehavior.shouldAttemptRefresh(
        detail: nil,
        hasAttemptedChapterIndexRefresh: false,
        chapterIndexRefreshService: MockSeriesChapterIndexRefreshService()
    ))
    #expect(SeriesDetailRefreshBehavior.shouldAttemptRefresh(
        detail: detail,
        hasAttemptedChapterIndexRefresh: false,
        chapterIndexRefreshService: MockSeriesChapterIndexRefreshService()
    ))
    #expect(!SeriesDetailRefreshBehavior.shouldAttemptRefresh(
        detail: detail,
        hasAttemptedChapterIndexRefresh: true,
        chapterIndexRefreshService: MockSeriesChapterIndexRefreshService()
    ))
    #expect(!SeriesDetailRefreshBehavior.shouldAttemptRefresh(
        detail: detail,
        hasAttemptedChapterIndexRefresh: false,
        chapterIndexRefreshService: nil
    ))
}

@Test func seriesDetailStartupKeepsLocalLoadAndBackgroundRefreshAsSeparatePhases() {
    let plan = SeriesDetailStartupPlan(localDetailLoaded: false, refreshAttempted: false)
    #expect(plan.nextPhase == .loadLocalDetail)

    let loadedPlan = SeriesDetailStartupPlan(localDetailLoaded: true, refreshAttempted: false)
    #expect(loadedPlan.nextPhase == .startBackgroundRefresh)

    let refreshedPlan = SeriesDetailStartupPlan(localDetailLoaded: true, refreshAttempted: true)
    #expect(refreshedPlan.nextPhase == .idle)
}

@Test func seriesDetailEntryUsesCachedHydratedDetailBeforeSeedShell() {
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(chapterLabel: "100", readState: .read),
            ChapterSummary.mock(chapterLabel: "101", readState: .unread)
        ]
    )
    let seed = LibrarySeriesSummary.mock(title: detail.title)

    let layout = SeriesDetailEntryLayout(
        cachedDetail: detail,
        seedSummary: seed,
        hasLoaded: false
    )

    #expect(layout.visibleState == .hydratedDetail)
    #expect(layout.exposesContinueAction)
    #expect(layout.startsBackgroundRefresh)
}

@Test func seriesDetailEntryIsActionableWhenLocalIndexHasNextChapter() {
    let chapters = (1...200).map { number in
        ChapterSummary.mock(
            chapterLabel: "\(number)",
            chapterNumber: Double(number),
            readState: number <= 100 ? .read : .unread
        )
    }
    let detail = SeriesDetailSnapshot.mock(chapters: chapters)

    let layout = SeriesDetailEntryLayout(
        cachedDetail: detail,
        seedSummary: nil,
        hasLoaded: false
    )

    #expect(detail.primaryActionTitle == "Start Chapter 101")
    #expect(detail.primaryChapter?.chapterLabel == "101")
    #expect(layout.visibleState == .hydratedDetail)
    #expect(layout.exposesContinueAction)
}

@Test func seriesDetailEntryContinuesForwardInProgressChapterFromLocalIndex() {
    let chapters = (1...200).map { number in
        ChapterSummary.mock(
            chapterLabel: "\(number)",
            chapterNumber: Double(number),
            readState: number < 100 ? .read : (number == 100 ? .inProgress(progressPercent: 0.42) : .unread)
        )
    }
    let detail = SeriesDetailSnapshot.mock(chapters: chapters)

    #expect(detail.primaryActionTitle == "Continue Chapter 100")
    #expect(detail.primaryChapter?.chapterLabel == "100")
}

@Test func seriesDetailEntryCanShowAllReadWhileEdgeRefreshRunsInBackground() {
    let chapters = (1...200).map { number in
        ChapterSummary.mock(
            chapterLabel: "\(number)",
            chapterNumber: Double(number),
            readState: .read
        )
    }
    let detail = SeriesDetailSnapshot.mock(chapters: chapters)
    let layout = SeriesDetailEntryLayout(
        cachedDetail: detail,
        seedSummary: nil,
        hasLoaded: false
    )

    #expect(detail.primaryActionTitle == "All Chapters Read")
    #expect(detail.primaryChapter == nil)
    #expect(layout.visibleState == .hydratedDetail)
    #expect(!layout.exposesContinueAction)
    #expect(layout.startsBackgroundRefresh)
}

@Test func seriesDetailCachePolicyPublishesHydratedMutationResults() {
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(chapterLabel: "100", readState: .read),
            ChapterSummary.mock(chapterLabel: "101", readState: .unread)
        ]
    )

    let policy = SeriesDetailCachePolicy(detail: detail)

    #expect(policy.cachedDetail == detail)
    #expect(!policy.clearsCachedDetail)
}

@Test func seriesDetailCachePolicyClearsRemovedOrUnavailableDetail() {
    let policy = SeriesDetailCachePolicy(detail: nil)

    #expect(policy.cachedDetail == nil)
    #expect(policy.clearsCachedDetail)
}

@Test func libraryDetailPrewarmPolicyDoesNotAutomaticallyPrewarmVisibleRows() {
    let policy = LibraryDetailPrewarmPolicy()

    #expect(!policy.automaticallyPrewarmsVisibleRows)
    #expect(policy.prewarmTrigger == .navigationOnly)
}

@Test func seriesDetailRefreshBehaviorReloadsOnlyWhenRefreshActuallyMutatesLocalData() {
    #expect(SeriesDetailRefreshBehavior.shouldReloadDetail(
        after: ChapterIndexRefreshOutcome(
            seriesID: UUID(),
            indexedChapterCount: 12,
            latestChapterLabel: "12",
            hasUnreadUpdates: true,
            didRefresh: true
        )
    ))
    #expect(!SeriesDetailRefreshBehavior.shouldReloadDetail(
        after: ChapterIndexRefreshOutcome(
            seriesID: UUID(),
            indexedChapterCount: 0,
            latestChapterLabel: nil,
            hasUnreadUpdates: false,
            didRefresh: false
        )
    ))
    #expect(!SeriesDetailRefreshBehavior.shouldReloadDetail(after: nil))
}

@Test func seriesDetailPrimaryActionStartsFirstUnreadWhenNoProgressExists() {
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(chapterLabel: "144", readState: .new),
            ChapterSummary.mock(chapterLabel: "143", readState: .unread),
            ChapterSummary.mock(chapterLabel: "142", readState: .read)
        ]
    )

    #expect(detail.primaryActionTitle == "Start Chapter 144")
    #expect(detail.primaryChapter?.chapterLabel == "144")
}

@Test func chapterListRecentReturnsMostRecentReadingActivity() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let chapters = [
        ChapterSummary.mock(chapterLabel: "1", chapterNumber: 1, lastReadAt: now.addingTimeInterval(-10)),
        ChapterSummary.mock(chapterLabel: "2", chapterNumber: 2, lastReadAt: now.addingTimeInterval(-40)),
        ChapterSummary.mock(chapterLabel: "3", chapterNumber: 3),
        ChapterSummary.mock(chapterLabel: "4", chapterNumber: 4, lastReadAt: now),
        ChapterSummary.mock(chapterLabel: "5", chapterNumber: 5, lastReadAt: now.addingTimeInterval(-20)),
        ChapterSummary.mock(chapterLabel: "6", chapterNumber: 6, lastReadAt: now.addingTimeInterval(-30))
    ]
    let detail = SeriesDetailSnapshot.mock(chapters: chapters)

    #expect(detail.chapterList(for: .recent).map(\.chapterLabel) == ["4", "1", "5", "6"])
}

@Test func chapterListAllGeneratesNumericRangeAndIncludesZeroOnlyWhenKnown() {
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(chapterLabel: "1", chapterNumber: 1),
            ChapterSummary.mock(chapterLabel: "4", chapterNumber: 4)
        ]
    )
    let zeroDetail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(chapterLabel: "0", chapterNumber: 0),
            ChapterSummary.mock(chapterLabel: "2", chapterNumber: 2)
        ]
    )

    let all = detail.chapterList(for: .all)

    #expect(all.map(\.chapterLabel) == ["1", "2", "3", "4"])
    #expect(all.first { $0.chapterLabel == "2" }?.sourceURL.absoluteString == "https://example.com/chapter-2")
    #expect(all.first { $0.chapterLabel == "2" }?.isOpenable == true)
    #expect(zeroDetail.chapterList(for: .all).map(\.chapterLabel) == ["0", "1", "2"])
}

@Test func chapterListAllDisablesGeneratedRowsWithoutSafeSourceURL() {
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(
                chapterLabel: "1",
                chapterNumber: 1,
                sourceURL: URL(string: "https://example.com/read")!
            ),
            ChapterSummary.mock(
                chapterLabel: "3",
                chapterNumber: 3,
                sourceURL: URL(string: "https://example.com/read")!
            )
        ]
    )

    let generated = detail.chapterList(for: .all).first { $0.chapterLabel == "2" }

    #expect(generated?.isGeneratedPlaceholder == true)
    #expect(generated?.isOpenable == false)
}

@Test func seriesDetailChapterListAnchorPrefersPrimaryChapterThenLatestReadChapter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let chapter106 = ChapterSummary.mock(
        chapterLabel: "106",
        chapterNumber: 106,
        readState: .read,
        lastReadAt: now
    )
    let chapter107 = ChapterSummary.mock(
        chapterLabel: "107",
        chapterNumber: 107,
        readState: .unread
    )
    let withNextTarget = SeriesDetailSnapshot.mock(chapters: [chapter106, chapter107])

    #expect(withNextTarget.chapterListAnchorID == chapter107.id)

    let allRead = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(
                chapterLabel: "105",
                chapterNumber: 105,
                readState: .read,
                lastReadAt: now.addingTimeInterval(-60)
            ),
            chapter106
        ]
    )

    #expect(allRead.chapterListAnchorID == chapter106.id)
}

@Test func seriesDetailInitialScrollBehaviorUsesNoDelayAndDisablesAnimation() {
    let anchorID = UUID()
    let behavior = SeriesDetailInitialScrollBehavior(anchorID: anchorID)
    let missing = SeriesDetailInitialScrollBehavior(anchorID: nil)

    #expect(behavior.shouldScroll)
    #expect(behavior.delayMilliseconds == 0)
    #expect(behavior.disablesAnimation)
    #expect(!missing.shouldScroll)
}

@Test func seriesDetailChapterSectionUsesSingleAllList() {
    let layout = SeriesDetailChapterSectionLayout()

    #expect(layout.showsSegmentedControl == false)
    #expect(layout.defaultMode == .all)
}

@Test func chapterRowStateExposesDistinctLabels() {
    #expect(ChapterReadState.new.displayLabel == "New")
    #expect(ChapterReadState.unread.displayLabel == "Unread")
    #expect(ChapterReadState.inProgress(progressPercent: 0.4).displayLabel == "40%")
    #expect(ChapterReadState.read.displayLabel == "Read")
    #expect(ChapterSummary.mock(isDownloaded: true).downloadLabel == "Downloaded")
}

@Test func homeReadingDashboardPrioritizesCurrentReadingAfterSearch() {
    let layout = HomeDashboardLayout()

    #expect(layout.contentPriority == [.search, .continueReading, .recentlyUpdated, .libraryPreview])
    #expect(layout.searchPlacement == .compactCommandBar)
    #expect(layout.refreshPlacement == .inlineStatus)
    #expect(layout.usesCircularTopAccessoryButtons == false)
}

@Test func homeSearchEntryUsesRestrainedBrowserCommandBarStyling() {
    let layout = HomeSearchEntryLayout()

    #expect(layout.placeholder == "Search the web or paste a chapter link")
    #expect(layout.height == 44)
    #expect(layout.cornerRadius == 10)
    #expect(layout.usesCapsuleShape == false)
    #expect(layout.horizontalPadding == ToonEdgeSpacing.medium)
}

@Test func homeChromeUsesQuietDashboardControls() {
    let accessory = HomeTopAccessoryLayout()
    let status = HomeRefreshStatusLayout(message: "Checked 2, found 1 update.")

    #expect(accessory.size == 40)
    #expect(accessory.cornerRadius == 10)
    #expect(accessory.usesCircleShape == false)
    #expect(status.message == "Checked 2, found 1 update.")
    #expect(status.cornerRadius == 10)
    #expect(status.usesBannerContainer == false)
}

@Test func homeReadingDashboardCardsUseCoverFirstNativeLayouts() {
    let featured = HomeSeriesCardLayout(style: .featured)
    let compact = HomeSeriesCardLayout(style: .compact)

    #expect(!featured.usesOuterCardContainer)
    #expect(!compact.usesOuterCardContainer)
    #expect(featured.coverWidth > compact.coverWidth)
    #expect(featured.coverHeight > compact.coverHeight)
    #expect(featured.progressHeight == 4)
    #expect(compact.progressHeight == 0)
    #expect(compact.titleLineLimit == 1)
}

@Test func homeReadingDashboardHeroHasProminentCurrentReadScale() {
    let featured = HomeSeriesCardLayout(style: .featured)

    #expect(featured.fixedHeight == 156)
    #expect(featured.coverWidth == 92)
    #expect(featured.coverHeight == 132)
    #expect(featured.cornerRadius == 6)
}

@Test func homeContinueReadingUsesRecentDistinctSeriesOrderingAndLimit() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let duplicateOlder = LibrarySeriesSummary.mock(
        id: UUID(uuidString: "4B81C535-7563-4184-9975-09409E5B9876")!,
        title: "A Recent",
        canonicalURL: URL(string: "https://example.com/a")!,
        lastReadAt: now.addingTimeInterval(-90),
        currentChapterLabel: "4"
    )
    let duplicateNewer = LibrarySeriesSummary.mock(
        id: UUID(uuidString: "B7427A73-B65B-47CC-9B45-AE87DA647FF1")!,
        title: "A Recent",
        canonicalURL: URL(string: "https://example.com/a")!,
        lastReadAt: now,
        currentChapterLabel: "5"
    )
    let b = LibrarySeriesSummary.mock(title: "B Recent", lastReadAt: now.addingTimeInterval(-10), currentChapterLabel: "9")
    let c = LibrarySeriesSummary.mock(title: "C Recent", lastReadAt: now.addingTimeInterval(-20), currentChapterLabel: "2")
    let d = LibrarySeriesSummary.mock(title: "D Recent", lastReadAt: now.addingTimeInterval(-30), currentChapterLabel: "7")
    let e = LibrarySeriesSummary.mock(title: "E Recent", lastReadAt: now.addingTimeInterval(-40), currentChapterLabel: "1")
    let snapshot = LibrarySnapshot(series: [e, d, c, b, duplicateOlder], recentReadSeries: [duplicateNewer])

    let summaries = HomeContinueReadingBuilder.summaries(from: snapshot)

    #expect(summaries.map(\.title) == ["A Recent", "B Recent", "C Recent", "D Recent"])
    #expect(summaries.first?.subtitle == "Continue Chapter 5")
    #expect(summaries.count == 4)
}

@Test func homeContinueReadingViewAllAvailabilityTracksRecentEntries() {
    let populated = HomeSnapshot(
        continueReading: [SeriesSummary(title: "A", subtitle: "Continue Chapter 1", progressPercent: 0.2, hasUnreadUpdates: false)],
        recentlyUpdated: [],
        library: []
    )
    let empty = HomeSnapshot(continueReading: [], recentlyUpdated: [], library: [])

    #expect(populated.showsContinueReadingViewAll)
    #expect(!empty.showsContinueReadingViewAll)
}

@Test func librarySeriesCardLayoutKeepsFixedHeightForMixedContent() {
    let short = LibrarySeriesSummary.mock(title: "Short")
    let long = LibrarySeriesSummary.mock(
        title: "The Extra’s Academy Survival Guide With A Very Long Title",
        hasUnreadUpdates: true,
        currentChapterLabel: "237"
    )
    let missingMetadata = LibrarySeriesSummary.mock(
        title: "No Metadata",
        currentChapterLabel: nil,
        latestChapterLabel: nil
    )
    let completed = LibrarySeriesSummary.mock(
        title: "Complete Series",
        progressPercent: 1,
        currentChapterLabel: nil
    )

    let layout = LibrarySeriesCardLayout.default

    #expect(layout.cardHeight(for: short) == layout.fixedCardHeight)
    #expect(layout.cardHeight(for: long) == layout.fixedCardHeight)
    #expect(layout.cardHeight(for: missingMetadata) == layout.fixedCardHeight)
    #expect(layout.cardHeight(for: completed) == layout.fixedCardHeight)
    #expect(layout.coverAspectRatio == 0.72)
    #expect(layout.coverSlotHeight == layout.coverHeight)
    #expect(layout.coverImageWidth == layout.coverHeight * layout.coverAspectRatio)
    #expect(layout.coverImageAlignment == .center)
    #expect(layout.coverSlotUsesFullCardWidth)
    #expect(layout.coverAppliesFrameBeforeDecoration)
    #expect(layout.titleLineLimit == 2)
    #expect(layout.metadataLineLimit == 1)
}

@Test func libraryComfortableCardLayoutReservesFullMetadataStack() {
    let layout = LibrarySeriesCardLayout.comfortable

    #expect(layout.fixedCardHeight >= layout.minimumRequiredHeight)
    #expect(layout.badgeRowHeight >= 24)
    #expect(layout.progressHeight >= 4)
    #expect(layout.titleLineLimit == 2)
}

@Test func librarySeriesCardMetadataShowsOnlyCurrentChapterNextToContinue() {
    let inProgress = LibrarySeriesSummary.mock(
        progressPercent: 0.37,
        currentChapterLabel: "237"
    )
    let completed = LibrarySeriesSummary.mock(
        progressPercent: 1,
        currentChapterLabel: "237"
    )
    let missingCurrentChapter = LibrarySeriesSummary.mock(
        currentChapterLabel: nil
    )

    #expect(LibrarySeriesCardContent(series: inProgress).metadata == "Continue Ch. 237")
    #expect(LibrarySeriesCardContent(series: completed).metadata == "100/100 chapters")
    #expect(LibrarySeriesCardContent(series: missingCurrentChapter).metadata == "50/100 chapters")
}

@Test func libraryCardMetadataPrefersResumeTargetOverLatestKnownChapter() {
    let resumeChapter = ChapterSummary(
        title: "First Chapter",
        chapterLabel: "1",
        chapterNumber: 1,
        sourceURL: URL(string: "https://example.com/series/chapter-1")!,
        readState: .inProgress(progressPercent: 0),
        isDownloaded: false,
        publishedAt: nil
    )
    let summary = LibrarySeriesSummary.mock(
        title: "The Shepherd Wizard | Asura Scans",
        currentChapterLabel: nil,
        latestChapterLabel: "236",
        resumeTarget: LibraryResumeTarget(chapter: resumeChapter)
    )
    let content = LibrarySeriesCardContent(series: summary)

    #expect(content.metadata == "Continue Ch. 1")
    #expect(content.compactMetadata == "Ch. 1")
    #expect(content.comfortableBadgeMetadata == "Ch. 1")
    #expect(content.listMetadata == "Ch. 1")
}

@Test func libraryCardMetadataDoesNotPresentLatestKnownAsCurrentWhenResumeTargetIsMissing() {
    let summary = LibrarySeriesSummary.mock(
        currentChapterLabel: nil,
        latestChapterLabel: "236",
        resumeTarget: nil
    )
    let content = LibrarySeriesCardContent(series: summary)

    #expect(content.compactMetadata != "Ch. 236")
    #expect(content.comfortableBadgeMetadata == nil)
    #expect(content.listMetadata != "Ch. 236")
}

@Test func libraryCardMetadataKeepsNewUpdateSeparateFromResumeChapter() {
    let resumeChapter = ChapterSummary(
        title: "First Chapter",
        chapterLabel: "1",
        chapterNumber: 1,
        sourceURL: URL(string: "https://example.com/chapter-1")!,
        readState: .unread,
        isDownloaded: false,
        publishedAt: nil
    )
    let summary = LibrarySeriesSummary.mock(
        hasUnreadUpdates: true,
        currentChapterLabel: nil,
        latestChapterLabel: "236",
        resumeTarget: LibraryResumeTarget(chapter: resumeChapter)
    )
    let content = LibrarySeriesCardContent(series: summary)

    #expect(content.comfortableBadgeMetadata == "Ch. 1")
    #expect(content.compactMetadata == "Ch. 1")
}

@Test func libraryCompactCardMetadataPrefersShortChapterLabel() {
    let latest = LibrarySeriesSummary.mock(
        currentChapterLabel: "3",
        latestChapterLabel: "237"
    )
    let currentOnly = LibrarySeriesSummary.mock(
        currentChapterLabel: "3",
        latestChapterLabel: nil
    )
    let noChapter = LibrarySeriesSummary.mock(
        currentChapterLabel: nil,
        latestChapterLabel: nil
    )
    let noisyCurrentWithLatest = LibrarySeriesSummary.mock(
        sourceDomain: "asurascans.com",
        currentChapterLabel: "Scans",
        latestChapterLabel: "16"
    )

    #expect(LibrarySeriesCardContent(series: latest).compactMetadata == "Ch. 3")
    #expect(LibrarySeriesCardContent(series: currentOnly).compactMetadata == "Ch. 3")
    #expect(LibrarySeriesCardContent(series: noChapter).compactMetadata == "50/100 chapters")
    #expect(LibrarySeriesCardContent(series: noisyCurrentWithLatest).compactMetadata == "50/100 chapters")
}

@Test func libraryComfortableCardMetadataShowsSourceWebsite() {
    let asura = LibrarySeriesSummary.mock(
        title: "The Regressed Mercenary",
        sourceDomain: "asurascans.com",
        canonicalURL: URL(string: "https://asurascans.com/comics/the-regressed-mercenarys-machinations-a80d257e/chapter/16")!,
        currentChapterLabel: "Scans",
        latestChapterLabel: "16"
    )

    #expect(LibrarySeriesCardContent(series: asura).sourceMetadata == "asurascans.com")
}

@Test func libraryComfortableCardBadgePrefersCurrentChapterOverLatestChapter() {
    let inProgress = LibrarySeriesSummary.mock(
        currentChapterLabel: "102",
        latestChapterLabel: "237"
    )
    let planned = LibrarySeriesSummary.mock(
        currentChapterLabel: nil,
        latestChapterLabel: "237"
    )
    let completed = LibrarySeriesSummary.mock(
        progressPercent: 1,
        currentChapterLabel: "102",
        latestChapterLabel: "237"
    )

    #expect(LibrarySeriesCardContent(series: inProgress).comfortableBadgeMetadata == "Ch. 102")
    #expect(LibrarySeriesCardContent(series: planned).comfortableBadgeMetadata == nil)
    #expect(LibrarySeriesCardContent(series: completed).comfortableBadgeMetadata == "Complete")
}

@Test func libraryListMetadataPrefersNumericChapterLabelOverNoisyCurrentLabel() {
    let noisyCurrent = LibrarySeriesSummary.mock(
        sourceDomain: "asurascans.com",
        currentChapterLabel: "Scans",
        latestChapterLabel: "16"
    )
    let numericCurrent = LibrarySeriesSummary.mock(
        currentChapterLabel: "237",
        latestChapterLabel: "300"
    )

    #expect(LibrarySeriesCardContent(series: noisyCurrent).listMetadata == "50/100 chapters")
    #expect(LibrarySeriesCardContent(series: numericCurrent).listMetadata == "Ch. 237")
}

@Test func libraryViewModePreferencesPersistSelectedDensity() {
    let suiteName = "ToonEdgeLibraryViewMode-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let preferences = LibraryViewPreferences(userDefaults: defaults)

    #expect(preferences.selectedViewMode == .comfortable)

    preferences.selectedViewMode = .list
    #expect(LibraryViewPreferences(userDefaults: defaults).selectedViewMode == .list)

    preferences.selectedViewMode = .compact
    #expect(LibraryViewPreferences(userDefaults: defaults).selectedViewMode == .compact)

    defaults.removePersistentDomain(forName: suiteName)
}

@Test func libraryNativeCollectionLayoutsUseDistinctGridDensity() {
    let comfortableGrid = LibraryGridLayout(mode: .comfortable)
    let compactGrid = LibraryGridLayout(mode: .compact)
    let listGrid = LibraryGridLayout(mode: .list)

    #expect(comfortableGrid.columnStyle == .fixedCount(2))
    #expect(compactGrid.columnStyle == .fixedCount(4))
    #expect(listGrid.columnStyle == .adaptiveMinimum(320))
    #expect(compactGrid.itemSpacing < comfortableGrid.itemSpacing)
    #expect(compactGrid.horizontalContentPadding <= comfortableGrid.horizontalContentPadding)
}

@Test func libraryGridCardsAvoidOuterGeneratedCardContainer() {
    #expect(!LibrarySeriesCardLayout.comfortable.usesOuterCardContainer)
    #expect(!LibrarySeriesCardLayout.compact.usesOuterCardContainer)
    #expect(LibrarySeriesCardLayout.compact.fixedCardHeight <= 150)
    #expect(LibrarySeriesCardLayout.compact.coverAspectRatio == 1)
    #expect(LibrarySeriesCardLayout.compact.titleLineLimit == 1)
    #expect(LibrarySeriesCardLayout.compact.progressHeight == 0)
    #expect(LibrarySeriesCardLayout.compact.badgeRowHeight == 0)
}

@Test func libraryViewModesExposeIncreasingDensityLayouts() {
    #expect(LibraryViewMode.allCases == [.comfortable, .compact, .list])
    #expect(LibraryViewMode.comfortable.title == "Comfortable")
    #expect(LibraryViewMode.compact.title == "Compact")
    #expect(LibraryViewMode.list.title == "List")

    let comfortable = LibrarySeriesCardLayout.comfortable
    let compact = LibrarySeriesCardLayout.compact
    let list = LibrarySeriesListRowLayout.default

    #expect(compact.fixedCardHeight < comfortable.fixedCardHeight)
    #expect(compact.coverHeight < comfortable.coverHeight)
    #expect(compact.cornerRadius <= comfortable.cornerRadius)
    #expect(list.rowHeight < compact.fixedCardHeight)
    #expect(list.cornerRadius <= compact.cornerRadius)
}

@Test func libraryChromeUsesRestrainedNativeCollectionStyling() {
    let filter = LibraryFilterChipLayout(isSelected: true)
    let inactiveFilter = LibraryFilterChipLayout(isSelected: false)
    let controls = LibraryCollectionControlsLayout(
        visibleSeries: [LibrarySeriesSummary.mock()],
        hasUpdateRefreshService: true,
        isRefreshing: false
    )

    #expect(filter.cornerRadius == 8)
    #expect(inactiveFilter.cornerRadius == 8)
    #expect(filter.usesCapsuleShape == false)
    #expect(!controls.usesLargeSummaryCard)
}

@Test func addToLibraryStatePickerDefaultsByOriginAndAllowsOverride() {
    #expect(AddToLibraryStatePickerModel.defaultState(for: .reader) == .reading)
    #expect(AddToLibraryStatePickerModel.defaultState(for: .browser) == .planned)
    #expect(AddToLibraryStatePickerModel.defaultState(for: .seriesDetail) == .planned)
    #expect(AddToLibraryStatePickerModel.availableStates == [.reading, .planned, .dropped, .completed])

    var model = AddToLibraryStatePickerModel(title: "Moonlit Edge", context: .reader)
    #expect(model.selectedState == .reading)

    model.select(.dropped)
    #expect(model.selectedState == .dropped)
}

private extension LibrarySeriesSummary {
    static func mock(
        id: UUID = UUID(),
        title: String = "Moonlit Edge",
        sourceDomain: String = "example.com",
        canonicalURL: URL? = nil,
        coverImageURL: URL? = nil,
        libraryState: LibraryCollectionState = .reading,
        progressPercent: Double = 0.5,
        chaptersRead: Int? = nil,
        totalKnownChapters: Int? = nil,
        hasUnreadUpdates: Bool = false,
        lastReadAt: Date? = Date(timeIntervalSince1970: 1_700_000_000),
        currentChapterLabel: String? = "42",
        latestChapterLabel: String? = "100",
        resumeTarget: LibraryResumeTarget? = nil
    ) -> LibrarySeriesSummary {
        LibrarySeriesSummary(
            id: id,
            title: title,
            sourceDomain: sourceDomain,
            canonicalURL: canonicalURL,
            coverImageURL: coverImageURL,
            progressPercent: progressPercent,
            chaptersRead: chaptersRead ?? Int(progressPercent * 100),
            totalKnownChapters: totalKnownChapters ?? 100,
            lastReadAt: lastReadAt,
            libraryState: libraryState,
            hasUnreadUpdates: hasUnreadUpdates,
            isCompleted: progressPercent >= 1,
            latestChapterLabel: latestChapterLabel,
            currentChapterLabel: currentChapterLabel,
            resumeTarget: resumeTarget
        )
    }
}

private extension SeriesDetailSnapshot {
    static func mock(
        title: String = "Moonlit Edge",
        synopsis: String = "A compact mock synopsis.",
        sourceDomain: String = "example.com",
        coverImageURL: URL? = nil,
        chapters: [ChapterSummary]
    ) -> SeriesDetailSnapshot {
        SeriesDetailSnapshot(
            id: UUID(),
            title: title,
            status: "Ongoing",
            synopsis: synopsis,
            sourceDomain: sourceDomain,
            coverImageURL: coverImageURL,
            isSaved: true,
            libraryState: .reading,
            progressPercent: 0.35,
            chaptersRead: chapters.filter { $0.readState == .read }.count,
            totalKnownChapters: chapters.count,
            hasUnreadUpdates: chapters.contains { $0.readState == .new },
            chapters: chapters
        )
    }
}

private extension ChapterSummary {
    static func mock(
        title: String? = nil,
        chapterLabel: String = "1",
        chapterNumber: Double? = 1,
        readState: ChapterReadState = .unread,
        isDownloaded: Bool = false,
        sourceURL: URL? = nil,
        lastReadAt: Date? = nil
    ) -> ChapterSummary {
        ChapterSummary(
            id: UUID(),
            title: title ?? "Chapter \(chapterLabel)",
            chapterLabel: chapterLabel,
            chapterNumber: chapterNumber,
            sourceURL: sourceURL ?? URL(string: "https://example.com/chapter-\(chapterLabel)")!,
            readState: readState,
            isDownloaded: isDownloaded,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastReadAt: lastReadAt
        )
    }
}
