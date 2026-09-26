import Foundation
import Testing
@testable import ToonEdgeAppCore

@Test func detectorNormalizesLazyLoadedImageSources() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Moonlit Edge Chapter 12",
        documentHeight: 12_000,
        viewportWidth: 390,
        images: [
            DetectionImageCandidate(
                src: "data:image/gif;base64,placeholder",
                lazySources: ["/cdn/chapter-12/001.jpg"],
                srcset: nil,
                width: 900,
                height: 1_400,
                top: 400,
                left: 0,
                className: "chapter-image",
                id: nil,
                alt: "page 1",
                parentSignature: "reader"
            )
        ]
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.candidates.first?.src == "https://example.com/cdn/chapter-12/001.jpg")
}

@Test func pageAnalysisScriptCollectsLazySrcsetAttributes() {
    #expect(PageAnalysisScript.javaScript.contains("data-srcset"))
    #expect(PageAnalysisScript.javaScript.contains("data-lazy-srcset"))
}

@Test func pageAnalysisScriptCollectsReaderSemanticHints() {
    #expect(PageAnalysisScript.javaScript.contains("data-reader-page-image"))
    #expect(PageAnalysisScript.javaScript.contains("semanticHints"))
}

@Test func pageAnalysisScriptCollectsChallengeSignals() {
    #expect(PageAnalysisScript.javaScript.contains("challengeSignals"))
    #expect(PageAnalysisScript.javaScript.contains("cf-mitigated"))
    #expect(PageAnalysisScript.javaScript.contains("too many requests"))
    #expect(PageAnalysisScript.javaScript.contains("rate limit"))
}

@Test func pageAnalysisScriptCollectsAdjacentChapterLinks() {
    #expect(PageAnalysisScript.javaScript.contains("previousChapterURL"))
    #expect(PageAnalysisScript.javaScript.contains("nextChapterURL"))
}

@Test func detectorClassifiesLongVerticalChapterAsHighConfidence() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Moonlit Edge Chapter 12",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: (1...8).map { index in
            DetectionImageCandidate(
                src: "https://img.examplecdn.com/moonlit/chapter-12/\(index).jpg",
                lazySources: [],
                srcset: nil,
                width: 900,
                height: 1_350,
                top: Double(index * 1_360),
                left: 0,
                className: "reading-content",
                id: nil,
                alt: nil,
                parentSignature: "reader-main"
            )
        }
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 8)
}

@Test func detectedReaderSessionPreservesPageDimensions() throws {
    let detector = GenericChapterDetector()
    let page = DetectionPageAnalysis(
        pageURL: try #require(URL(string: "https://example.com/series/chapter-12")),
        title: "Chapter 12",
        documentHeight: 30_000,
        viewportWidth: 390,
        images: chapterImages(host: "img.example.com")
    )

    let result = detector.detect(page: page)
    let session = try #require(result.readerSession)

    #expect(session.pageMetadata.count == session.imageURLs.count)
    #expect(session.pageMetadata.first?.pixelWidth == 900)
    #expect(session.pageMetadata.first?.pixelHeight == 1350)
}

@Test func detectorKeepsThumbnailGridAtLowConfidence() throws {
    let pageURL = try #require(URL(string: "https://shop.example.com/products"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Products",
        documentHeight: 2_400,
        viewportWidth: 390,
        images: (1...20).map { index in
            DetectionImageCandidate(
                src: "https://shop.example.com/thumbs/\(index).jpg",
                lazySources: [],
                srcset: nil,
                width: 160,
                height: 160,
                top: Double((index / 2) * 180),
                left: index.isMultiple(of: 2) ? 0 : 180,
                className: "product thumbnail",
                id: nil,
                alt: "product thumbnail",
                parentSignature: "grid"
            )
        }
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerSession == nil)
}

@Test func detectorClassifiesSparseButUsableChapterAsMediumConfidence() throws {
    let pageURL = try #require(URL(string: "https://example.com/read/moonlit-12"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Moonlit Edge 12",
        documentHeight: 7_000,
        viewportWidth: 390,
        images: (1...3).map { index in
            DetectionImageCandidate(
                src: "https://cdn.example.com/ch12/\(index).jpg",
                lazySources: [],
                srcset: nil,
                width: 820,
                height: 1_200,
                top: Double(index * 1_220),
                left: 0,
                className: "chapter-page",
                id: nil,
                alt: nil,
                parentSignature: "chapter-body"
            )
        }
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.confidence == .medium)
    #expect(result.readerSession?.imageURLs.count == 3)
}

@Test func genericDetectorExcludesLargeAdImagesOutsideReaderFlow() throws {
    let page = DetectionPageAnalysis(
        pageURL: try #require(URL(string: "https://example.com/series/chapter-12")),
        title: "Chapter 12",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: [
            DetectionImageCandidate(
                src: "https://ads.example.com/banner.jpg",
                lazySources: [],
                srcset: nil,
                width: 1_200,
                height: 1_600,
                top: 120,
                left: 0,
                className: "sidebar-ad hero-banner",
                id: nil,
                alt: nil,
                parentSignature: "sidebar ad-container"
            ),
            DetectionImageCandidate(
                src: "https://cdn.example.com/pages/001.jpg",
                lazySources: [],
                srcset: nil,
                width: 900,
                height: 1_500,
                top: 2_000,
                left: 0,
                className: "chapter-page",
                id: nil,
                alt: nil,
                parentSignature: "reader pages"
            ),
            DetectionImageCandidate(
                src: "https://cdn.example.com/pages/002.jpg",
                lazySources: [],
                srcset: nil,
                width: 900,
                height: 1_500,
                top: 3_600,
                left: 0,
                className: "chapter-page",
                id: nil,
                alt: nil,
                parentSignature: "reader pages"
            )
        ]
    )

    let candidates = GenericChapterDetector().normalizedCandidates(from: page)

    #expect(candidates.map(\.src) == [
        "https://cdn.example.com/pages/001.jpg",
        "https://cdn.example.com/pages/002.jpg"
    ])
}

@Test func detectorClassifiesReaderTaggedImagesBeforeDimensionsLoad() throws {
    let pageURL = try #require(URL(string: "https://reader.example.com/series/sample/chapter-32"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Sample Chapter 32",
        documentHeight: 2_400,
        viewportWidth: 390,
        images: (1...11).map { index in
            DetectionImageCandidate(
                src: "https://storage.example.com/upload/series/sample/32/\(String(format: "%02d", index)).webp",
                lazySources: [],
                srcset: nil,
                width: 0,
                height: 0,
                top: Double(index),
                left: 0,
                className: "h-auto w-full object-contain",
                id: nil,
                alt: "Sample Chapter 32 Page \(index)",
                parentSignature: nil,
                semanticHints: ["data-reader-page-image", "data-reader-index"]
            )
        }
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 11)
}

@Test func detectorKeepsChallengePagesOutOfReaderEvenWhenImagesLookUsable() throws {
    let pageURL = try #require(URL(string: "https://blocked.example.com/chapter-1"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Just a moment...",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: chapterImages(host: "blocked.example.com"),
        challengeSignals: ["cf-mitigated:challenge"]
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerSession == nil)
    #expect(result.diagnostics.messages.contains("challengePage=true"))
}

@Test func siteProfileRegistryMatchesDomainsAndSubdomains() throws {
    let registry = SiteProfileRegistry(
        profiles: [
            SiteProfile(
                domain: "example.com",
                supportTier: .enabledPublic,
                imageSelectorHints: ["reader"]
            )
        ]
    )

    let rootURL = try #require(URL(string: "https://example.com/chapter-12"))
    let subdomainURL = try #require(URL(string: "https://cdn.example.com/chapter-12"))

    #expect(registry.profile(for: rootURL)?.domain == "example.com")
    #expect(registry.profile(for: subdomainURL)?.domain == "example.com")
}

@Test func defaultSiteProfileRegistryIncludesInitialSupportTiers() throws {
    let registry = SiteProfileRegistry.default

    #expect(registry.profile(for: try #require(URL(string: "https://webtoons.com/en/action/sample/episode-1")))?.supportTier == .browserOnly)
    #expect(registry.profile(for: try #require(URL(string: "https://m.webtoons.com/en/action/sample/viewer")))?.compatibilityClass == .browserOnly)
    #expect(registry.profile(for: try #require(URL(string: "https://globalcomix.com/c/sample/chapters/en/1")))?.supportTier == .browserOnly)
    #expect(registry.profile(for: try #require(URL(string: "https://www.globalcomix.com/c/sample/chapters/en/1")))?.compatibilityClass == .browserOnly)
    #expect(registry.profile(for: try #require(URL(string: "https://asuracomic.net/series/sample/chapter-1")))?.supportTier == .approvedNonPromoted)
    #expect(registry.profile(for: try #require(URL(string: "https://asurascans.com/series/sample/chapter-1")))?.supportTier == .approvedNonPromoted)
    #expect(registry.profile(for: try #require(URL(string: "https://manhwatop.com/manga/sample/chapter-1")))?.supportTier == .approvedNonPromoted)
    #expect(registry.profile(for: try #require(URL(string: "https://manhuaus.com/manga/sample/chapter-1")))?.supportTier == .approvedNonPromoted)
}

@Test func defaultSiteProfileRegistryIncludesRepresentativeCompatibilityClasses() throws {
    let registry = SiteProfileRegistry.default

    #expect(registry.profile(for: try #require(URL(string: "https://asurascans.com/comics/sample/chapter/1")))?.compatibilityClass == .embeddedHTML)
    #expect(registry.profile(for: try #require(URL(string: "https://mangakatana.com/manga/sample/c1")))?.compatibilityClass == .hydratedDOM)
    #expect(registry.profile(for: try #require(URL(string: "https://mangafire.to/read/sample/en/chapter-1")))?.compatibilityClass == .browserSession)
    #expect(registry.profile(for: try #require(URL(string: "https://manhwatop.com/manga/sample/chapter-1")))?.compatibilityClass == .hydratedDOM)
    #expect(registry.profile(for: try #require(URL(string: "https://manhuaus.com/manga/sample/chapter-1")))?.compatibilityClass == .browserSession)
    #expect(registry.profile(for: try #require(URL(string: "https://mangapill.com/chapters/sample/chapter-1")))?.compatibilityClass == .hydratedDOM)
    #expect(registry.profile(for: try #require(URL(string: "https://www.mangahere.cc/manga/sample/c006/15.html")))?.compatibilityClass == .paginatedSinglePage)
}

@Test func relatedAsuraDomainsReuseEmbeddedHTMLTemplate() throws {
    let registry = SiteProfileRegistry.default
    let asuraComicURL = try #require(URL(string: "https://asuracomic.net/series/sample/chapter-1"))
    let asuraScansURL = try #require(URL(string: "https://asurascans.com/comics/sample/chapter/1"))
    let asuraComic = try #require(registry.profile(for: asuraComicURL))
    let asuraScans = try #require(registry.profile(for: asuraScansURL))

    #expect(asuraComic.template == asuraScans.template)
}

@Test func canonicalSeriesURLResolverHandlesAsuraComicChapterURLs() throws {
    let chapterURL = try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/97"))

    let seriesURL = CanonicalSeriesURLResolver.seriesURL(for: chapterURL)

    #expect(seriesURL.absoluteString == "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5")
}

@Test func siteProfilesExposeSelectorHintExtractionStrategy() throws {
    let profile = SiteProfile(
        domain: "reader.example.com",
        supportTier: .enabledPublic,
        extractionStrategy: .selectorHints(["main-reader"])
    )

    #expect(profile.imageSelectorHints == ["main-reader"])
    #expect(profile.extractionStrategy == .selectorHints(["main-reader"]))
}

@Test func approvedNonPromotedProfilesAreNotSearchSuggestionSources() {
    let registry = SiteProfileRegistry.default
    let promotedDomains = registry.promotedSuggestionDomains

    #expect(!promotedDomains.contains("webtoons.com"))
    #expect(!promotedDomains.contains("globalcomix.com"))
    #expect(!promotedDomains.contains("asuracomic.net"))
    #expect(!promotedDomains.contains("asurascans.com"))
    #expect(!promotedDomains.contains("manhwatop.com"))
}

@Test func protectedReaderImagesCannotProduceReaderPresentation() throws {
    for host in ["m.webtoons.com", "www.globalcomix.com"] {
        let page = DetectionPageAnalysis(
            pageURL: try #require(URL(string: "https://\(host)/sample/chapter-1/viewer")),
            title: "Sample Chapter 1",
            documentHeight: 20_000,
            viewportWidth: 390,
            images: chapterImages(host: "images.example.com")
        )

        let result = ProfileAwareChapterDetector().detect(page: page)

        #expect(result.confidence == .low)
        #expect(result.readerSession == nil)
        #expect(result.diagnostics.parserPath == .browserOnlyProfile)
    }
}

@Test func vortexRouteFixtureProducesOrderedReaderSession() throws {
    let page = try detectionFixture(named: "vortex_spa_chapter_169")
    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.sourceURL == page.pageURL)
    #expect(result.readerSession?.imageURLs.map(\.lastPathComponent) == [
        "001.jpg", "002.jpg", "003.jpg", "004.jpg", "005.jpg", "006.jpg", "007.jpg", "008.jpg"
    ])
}

@Test func comizyRedirectFixtureRetainsCanonicalURLAndOrderedImages() throws {
    let page = try detectionFixture(named: "comizy_redirected_chapter")
    let result = ProfileAwareChapterDetector().detect(page: page)
    let session = try #require(result.readerSession)

    #expect(session.sourceURL.host() == "comizy.io")
    #expect(session.seriesURL.absoluteString == "https://comizy.io/kono-manga-no-heroine-wa-morisaki-amane-desu/")
    #expect(session.imageURLs.count == 10)
    #expect(session.imageURLs.map(\.lastPathComponent) == (1...10).map { String(format: "%03d.jpg", $0) })
}

@Test func remediationSiteFixturesRemainSanitizedOrderedAndPolicyAccurate() throws {
    let readableFixtures = [
        "vortex_spa_chapter_169",
        "mangakatana_hydrated_dom",
        "mangapill_hydrated_dom",
        "comizy_redirected_chapter"
    ]

    for name in readableFixtures {
        let page = try detectionFixture(named: name)
        let result = ProfileAwareChapterDetector().detect(page: page)
        let session = try #require(result.readerSession)
        #expect(result.confidence == .high)
        #expect(session.imageURLs.count == page.images.count)
        #expect(session.imageURLs.allSatisfy { $0.host() == "images.example.test" })
        #expect(session.imageURLs == session.imageURLs.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        })
    }

    let challenge = try detectionFixture(named: "manhwatop_browser_only")
    let challengeResult = ProfileAwareChapterDetector().detect(page: challenge)
    #expect(challengeResult.confidence == .low)
    #expect(challengeResult.readerSession == nil)
    #expect(!challenge.challengeSignals.isEmpty)
}

@Test func embeddedHTMLProfileUsesSiteProfileDetectionPath() throws {
    let page = try detectionFixture(named: "asura_embedded_html")

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 8)
    #expect(result.diagnostics.parserPath == .siteProfile)
    #expect(result.diagnostics.compatibilityClass == .embeddedHTML)
}

@Test func hydratedDOMProfileUsesSiteProfileDetectionPath() throws {
    let page = try detectionFixture(named: "mangakatana_hydrated_dom")

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 8)
    #expect(result.diagnostics.parserPath == .siteProfile)
    #expect(result.diagnostics.compatibilityClass == .hydratedDOM)
}

@Test func secondHydratedDOMSiteReusesExistingTemplate() throws {
    let page = try detectionFixture(named: "mangapill_hydrated_dom")

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 5)
    #expect(result.diagnostics.parserPath == .siteProfile)
    #expect(result.diagnostics.compatibilityClass == .hydratedDOM)
}

@Test func browserSessionProfileSuppressesUnsafeGenericConversion() throws {
    let page = try detectionFixture(named: "mangafire_browser_session")

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerSession == nil)
    #expect(result.diagnostics.parserPath == .browserSessionProfile)
    #expect(result.diagnostics.compatibilityClass == .browserSession)
    #expect(result.retryRecommendation == .browserSessionFollowUp)
}

@Test func browserSessionFollowUpCanPromoteAfterHydration() throws {
    let page = try detectionFixture(named: "mangafire_browser_session")

    let result = ProfileAwareChapterDetector().detectBrowserSessionFollowUp(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 8)
    #expect(result.retryRecommendation == .none)
}

@Test func manhuaUSBrowserSessionFollowUpPromotesOnlyReaderImages() throws {
    let pageURL = try #require(URL(string: "https://manhuaus.com/manga/the-cold-blooded-warrior/chapter-54/"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "The Cold-Blooded Warrior - Chapter 54",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: [
            DetectionImageCandidate(
                src: "https://ads.example.com/tall-popup.jpg",
                lazySources: [],
                srcset: nil,
                width: 900,
                height: 1_350,
                top: 80,
                left: 0,
                className: "popup-ad",
                id: "ad-modal",
                alt: "advertisement",
                parentSignature: "modal popup ad"
            )
        ] + (1...8).map { index in
            DetectionImageCandidate(
                src: "https://manhuaus.com/wp-content/uploads/the-cold-blooded-warrior/54/\(index).jpg",
                lazySources: [],
                srcset: nil,
                width: 900,
                height: 1_350,
                top: Double(index * 1_360),
                left: 0,
                className: "wp-manga-chapter-img",
                id: nil,
                alt: "The Cold-Blooded Warrior Chapter 54 page \(index)",
                parentSignature: "reading-content manga-reading-content"
            )
        }
    )

    let initial = ProfileAwareChapterDetector().detect(page: page)
    let followUp = ProfileAwareChapterDetector().detectBrowserSessionFollowUp(page: page)

    #expect(initial.confidence == .low)
    #expect(initial.retryRecommendation == .browserSessionFollowUp)
    #expect(followUp.confidence == .high)
    #expect(followUp.readerSession?.imageURLs.count == 8)
    #expect(followUp.readerSession?.imageURLs.first?.absoluteString.contains("ads.example.com") == false)
}

@Test func browserSessionFollowUpWithoutViableCandidatesStaysLowConfidence() throws {
    var page = try detectionFixture(named: "mangafire_browser_session")
    page.images = []

    let result = ProfileAwareChapterDetector().detectBrowserSessionFollowUp(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerSession == nil)
    #expect(result.retryRecommendation == .none)
}

@Test func challengePagesDoNotRecommendBrowserSessionRetry() throws {
    var page = try detectionFixture(named: "mangafire_browser_session")
    page.title = "Just a moment..."
    page.challengeSignals = ["cf-mitigated:challenge"]

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.retryRecommendation == .none)
}

@Test func profileAwareDetectorLogsStructuredDiagnostics() throws {
    let logger = SpyDetectionDiagnosticsLogger()
    let pageURL = try #require(URL(string: "https://unknown.example.com/series/chapter-12"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Chapter 12",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: chapterImages(host: "unknown.example.com")
    )

    _ = ProfileAwareChapterDetector(
        registry: SiteProfileRegistry(profiles: []),
        diagnosticsLogger: logger
    ).detect(page: page)

    #expect(logger.loggedDiagnostics.count == 1)
    #expect(logger.loggedDiagnostics.first?.confidence == .high)
    #expect(logger.loggedDiagnostics.first?.parserPath == .genericHeuristic)
}

@Test func manhwaTopChallengePageSuppressesReaderConversion() throws {
    let page = try detectionFixture(named: "manhwatop_browser_only")

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerSession == nil)
    #expect(result.diagnostics.parserPath == .browserSessionProfile)
    #expect(result.diagnostics.compatibilityClass == .hydratedDOM)
}

@Test func manhwaTopProfileCanPromoteViableChapterIntoReader() throws {
    let page = DetectionPageAnalysis(
        pageURL: try #require(URL(string: "https://manhwatop.com/manga/past-life-returner/chapter-1/")),
        title: "Past Life Returner - Chapter 1",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: (1...6).map { index in
            DetectionImageCandidate(
                src: "https://cdn.manhwatop.com/past-life-returner/1/\(index).jpg",
                lazySources: [],
                srcset: nil,
                width: 900,
                height: 1_350,
                top: Double(index * 1_360),
                left: 0,
                className: "chapter-content",
                id: nil,
                alt: "page \(index)",
                parentSignature: "main-reader chapter-content"
            )
        }
    )

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 6)
    #expect(result.diagnostics.parserPath == .siteProfile)
}

@Test func manhwaTopProfileRejectsBlankPlaceholderImages() throws {
    let page = DetectionPageAnalysis(
        pageURL: try #require(URL(string: "https://manhwatop.com/manga/past-life-returner/chapter-1/")),
        title: "Past Life Returner - Chapter 1",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: [
            DetectionImageCandidate(
                src: "https://manhwatop.com/wp-content/uploads/blank.gif",
                lazySources: [],
                srcset: nil,
                width: 900,
                height: 1_350,
                top: 100,
                left: 0,
                className: "chapter-content",
                id: nil,
                alt: nil,
                parentSignature: "main-reader chapter-content"
            )
        ]
    )

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerSession == nil)
}

@Test func paginatedSinglePageProfileReportsUnsupportedPaginatedDiagnostics() throws {
    let page = try detectionFixture(named: "mangahere_paginated_single_page")

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerSession == nil)
    #expect(result.retryRecommendation == .none)
    #expect(result.diagnostics.parserPath == .unsupportedPaginatedProfile)
    #expect(result.diagnostics.compatibilityClass == .paginatedSinglePage)
}

@Test func profileAwareDetectorUsesProfileSelectorHintsBeforeGenericFallback() throws {
    let pageURL = try #require(URL(string: "https://reader.example.com/series/chapter-12"))
    let registry = SiteProfileRegistry(
        profiles: [
            SiteProfile(
                domain: "reader.example.com",
                supportTier: .enabledPublic,
                imageSelectorHints: ["main-reader"]
            )
        ]
    )
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Chapter 12",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: chapterImages(host: "reader.example.com") + [
            DetectionImageCandidate(
                src: "https://reader.example.com/sidebar/ad.jpg",
                lazySources: [],
                srcset: nil,
                width: 700,
                height: 900,
                top: 100,
                left: 260,
                className: "sidebar-promo",
                id: nil,
                alt: nil,
                parentSignature: "sidebar"
            )
        ]
    )

    let result = ProfileAwareChapterDetector(registry: registry).detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 8)
    #expect(result.diagnostics.parserPath == .siteProfile)
    #expect(result.diagnostics.profileDomain == "reader.example.com")
}

@Test func detectionDiagnosticsExposeConfidenceAndParserPath() throws {
    let pageURL = try #require(URL(string: "https://unknown.example.com/series/chapter-12"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Chapter 12",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: chapterImages(host: "unknown.example.com")
    )

    let result = ProfileAwareChapterDetector(registry: SiteProfileRegistry(profiles: [])).detect(page: page)

    #expect(result.diagnostics.confidence == .high)
    #expect(result.diagnostics.parserPath == .genericHeuristic)
    #expect(result.diagnostics.score == result.score)
    #expect(result.diagnostics.messages.contains("confidence=high"))
}

@Test func detectedReaderSessionPreservesAdjacentChapterLinks() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let previousURL = try #require(URL(string: "https://example.com/series/chapter-11"))
    let nextURL = try #require(URL(string: "https://example.com/series/chapter-13"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Chapter 12",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: chapterImages(host: "example.com"),
        previousChapterURL: previousURL,
        nextChapterURL: nextURL
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.readerSession?.previousChapter?.sourceURL == previousURL)
    #expect(result.readerSession?.nextChapter?.sourceURL == nextURL)
    #expect(result.readerSession?.launchOrigin == .browser)
}

@Test func detectedReaderSessionInfersAdjacentChapterLinksFromNumericURLWhenLinksAreMissing() throws {
    let pageURL = try #require(URL(string: "https://asurascans.com/comics/the-cold-blooded-warrior-46f09241/chapter/3"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "The Cold-Blooded Warrior Chapter 3",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: chapterImages(host: "asurascans.com")
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.readerSession?.previousChapter?.sourceURL == URL(string: "https://asurascans.com/comics/the-cold-blooded-warrior-46f09241/chapter/2")!)
    #expect(result.readerSession?.nextChapter?.sourceURL == URL(string: "https://asurascans.com/comics/the-cold-blooded-warrior-46f09241/chapter/4")!)
}

@MainActor
@Test func browserAutoOpensReaderOnlyForHighConfidence() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let viewModel = BrowserViewModel(startPoint: .url(pageURL.absoluteString))
    let session = MockReaderSession(
        seriesTitle: "Moonlit Edge",
        chapterTitle: "Chapter 12",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))]
    )

    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: pageURL,
            confidence: .high,
            score: 100,
            candidates: [],
            readerSession: session,
            diagnostics: .init(confidence: .high, score: 100, parserPath: .genericHeuristic)
        )
    )

    #expect(viewModel.pendingReaderSession == session)
    #expect(!viewModel.showsCleanModeCTA)
}

@MainActor
@Test func browserShowsCTAForMediumConfidenceAndManualOverridePresentsReader() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let viewModel = BrowserViewModel(startPoint: .url(pageURL.absoluteString))
    let session = MockReaderSession(
        seriesTitle: "Moonlit Edge",
        chapterTitle: "Chapter 12",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))]
    )

    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: pageURL,
            confidence: .medium,
            score: 60,
            candidates: [],
            readerSession: session,
            diagnostics: .init(confidence: .medium, score: 60, parserPath: .genericHeuristic)
        )
    )

    #expect(viewModel.pendingReaderSession == nil)
    #expect(viewModel.showsCleanModeCTA)

    viewModel.enterCleanModeManually()

    #expect(viewModel.pendingReaderSession == session)
    #expect(!viewModel.showsCleanModeCTA)
}

@MainActor
@Test func browserLeavesLowConfidencePageInBrowser() throws {
    let pageURL = try #require(URL(string: "https://example.com/article"))
    let viewModel = BrowserViewModel(startPoint: .url(pageURL.absoluteString))

    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: pageURL,
            confidence: .low,
            score: 10,
            candidates: [],
            readerSession: nil,
            diagnostics: .init(confidence: .low, score: 10, parserPath: .genericHeuristic)
        )
    )

    #expect(viewModel.pendingReaderSession == nil)
    #expect(!viewModel.showsCleanModeCTA)
}

private func chapterImages(host: String, parentSignature: String = "main-reader") -> [DetectionImageCandidate] {
    (1...8).map { index in
        DetectionImageCandidate(
            src: "https://\(host)/series/chapter-12/\(index).jpg",
            lazySources: [],
            srcset: nil,
            width: 900,
            height: 1_350,
            top: Double(index * 1_360),
            left: 0,
            className: "reading-content",
            id: nil,
            alt: nil,
            parentSignature: parentSignature
        )
    }
}

private func detectionFixture(named name: String) throws -> DetectionPageAnalysis {
    let fixtureURL = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    let data = try Data(contentsOf: fixtureURL)
    return try JSONDecoder().decode(DetectionPageAnalysis.self, from: data)
}

private final class SpyDetectionDiagnosticsLogger: DetectionDiagnosticsLogging, @unchecked Sendable {
    private(set) var loggedDiagnostics: [DetectionDiagnostics] = []

    func log(_ diagnostics: DetectionDiagnostics, pageURL: URL) {
        loggedDiagnostics.append(diagnostics)
    }
}
