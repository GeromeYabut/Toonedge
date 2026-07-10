import Foundation
import Testing
@testable import ToonEdgeAppCore

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

@Test func librarySummaryPillExposesRefreshOnlyWhenServiceExists() {
    let series = [
        LibrarySeriesSummary.mock(title: "A"),
        LibrarySeriesSummary.mock(title: "B")
    ]

    let refreshable = LibrarySummaryPillLayout(
        segment: .reading,
        visibleSeries: series,
        hasUpdateRefreshService: true,
        isRefreshing: false
    )
    let localOnly = LibrarySummaryPillLayout(
        segment: .reading,
        visibleSeries: series,
        hasUpdateRefreshService: false,
        isRefreshing: false
    )

    #expect(refreshable.title == "Reading Library")
    #expect(refreshable.message == "2 saved titles")
    #expect(refreshable.refreshButtonIsVisible)
    #expect(!localOnly.refreshButtonIsVisible)
}

@Test func librarySummaryPillUsesUpdateCountAndRefreshIconState() {
    let series = [
        LibrarySeriesSummary.mock(title: "A", hasUnreadUpdates: true),
        LibrarySeriesSummary.mock(title: "B", hasUnreadUpdates: false),
        LibrarySeriesSummary.mock(title: "C", hasUnreadUpdates: true)
    ]

    let idle = LibrarySummaryPillLayout(
        segment: .recent,
        visibleSeries: series,
        hasUpdateRefreshService: true,
        isRefreshing: false
    )
    let refreshing = LibrarySummaryPillLayout(
        segment: .recent,
        visibleSeries: series,
        hasUpdateRefreshService: true,
        isRefreshing: true
    )

    #expect(idle.message == "2 with new chapters")
    #expect(idle.refreshSystemImage == "arrow.clockwise")
    #expect(refreshing.refreshSystemImage == "hourglass")
    #expect(idle.refreshAccessibilityLabel == "Check for new chapters")
}

@Test func libraryRefreshFeedbackLayoutIsDismissibleAndAutoExpires() {
    let layout = LibraryRefreshFeedbackLayout(message: "2 checked, 1 update")

    #expect(layout.title == "Updated")
    #expect(layout.message == "2 checked, 1 update")
    #expect(layout.presentationStyle == .floatingOverlay)
    #expect(layout.overlayAlignment == .bottomTrailing)
    #expect(layout.maximumWidth == 280)
    #expect(layout.contentSize == .compact)
    #expect(layout.accentColorRole == .purple)
    #expect(!layout.reservesContentSpace)
    #expect(layout.dismissAccessibilityLabel == "Dismiss update refresh")
    #expect(layout.autoDismissDelay == 5)
}

@Test func libraryContentLayoutKeepsRefreshFeedbackOutOfFlow() {
    let layout = LibraryContentLayout(refreshFeedback: LibraryRefreshFeedbackLayout(message: "2 checked, 1 update"))

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

@Test func sleepyLibraryEmptyStateMascotImageIsBundled() throws {
    let imageURL = try #require(ToonEdgeAppCoreResources.urlForImage(named: "sleepy transparent", extension: "png"))

    #expect(imageURL.lastPathComponent == "sleepy transparent.png")
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

@Test func seriesDetailRefreshBehaviorAttemptsOnlyWhenServiceExistsAndNotYetTried() {
    #expect(SeriesDetailRefreshBehavior.shouldAttemptRefresh(
        hasAttemptedChapterIndexRefresh: false,
        chapterIndexRefreshService: MockSeriesChapterIndexRefreshService()
    ))
    #expect(!SeriesDetailRefreshBehavior.shouldAttemptRefresh(
        hasAttemptedChapterIndexRefresh: true,
        chapterIndexRefreshService: MockSeriesChapterIndexRefreshService()
    ))
    #expect(!SeriesDetailRefreshBehavior.shouldAttemptRefresh(
        hasAttemptedChapterIndexRefresh: false,
        chapterIndexRefreshService: nil
    ))
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
        canonicalURL: URL? = nil,
        libraryState: LibraryCollectionState = .reading,
        progressPercent: Double = 0.5,
        hasUnreadUpdates: Bool = false,
        lastReadAt: Date? = Date(timeIntervalSince1970: 1_700_000_000),
        currentChapterLabel: String? = "42",
        latestChapterLabel: String? = "100"
    ) -> LibrarySeriesSummary {
        LibrarySeriesSummary(
            id: id,
            title: title,
            sourceDomain: "example.com",
            canonicalURL: canonicalURL,
            coverImageURL: nil,
            progressPercent: progressPercent,
            chaptersRead: Int(progressPercent * 100),
            totalKnownChapters: 100,
            lastReadAt: lastReadAt,
            libraryState: libraryState,
            hasUnreadUpdates: hasUnreadUpdates,
            isCompleted: progressPercent >= 1,
            latestChapterLabel: latestChapterLabel,
            currentChapterLabel: currentChapterLabel
        )
    }
}

private extension SeriesDetailSnapshot {
    static func mock(synopsis: String = "A compact mock synopsis.", chapters: [ChapterSummary]) -> SeriesDetailSnapshot {
        SeriesDetailSnapshot(
            id: UUID(),
            title: "Moonlit Edge",
            status: "Ongoing",
            synopsis: synopsis,
            sourceDomain: "example.com",
            coverImageURL: nil,
            isSaved: true,
            libraryState: .reading,
            progressPercent: 0.35,
            chaptersRead: 12,
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
