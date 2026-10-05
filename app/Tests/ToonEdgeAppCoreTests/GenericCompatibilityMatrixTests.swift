import Foundation
import Testing
@testable import ToonEdgeAppCore

@Test func matrixManifestRejectsMissingAndUnclassifiedFixtures() throws {
    let rows = try matrixTestManifest().cases
    let fixture: Set<String> = ["matrix_payload_embedded.json"]
    #expect(throws: (any Error).self) {
        try validateMatrixInventory(rows: rows, sourceFiles: [], bundledFiles: fixture)
    }
    #expect(throws: (any Error).self) {
        try validateMatrixInventory(rows: rows, sourceFiles: fixture, bundledFiles: [])
    }
    let unclassified = fixture.union(["matrix_dom_unclassified.html"])
    #expect(throws: (any Error).self) {
        try validateMatrixInventory(rows: rows, sourceFiles: unclassified, bundledFiles: fixture)
    }
    #expect(throws: (any Error).self) {
        try validateMatrixInventory(rows: rows, sourceFiles: fixture, bundledFiles: unclassified)
    }
}

@Test func matrixManifestRejectsUnknownVersion() throws {
    #expect(throws: (any Error).self) { try matrixTestManifest(version: 2) }
}

@Test func matrixManifestRejectsDuplicateIDs() throws {
    #expect(throws: (any Error).self) { try matrixTestManifest(rows: [matrixTestRow(), matrixTestRow()]) }
}

@Test(arguments: ["../matrix_payload_embedded.json", "/matrix_payload_embedded.json",
                  "nested/matrix_payload_embedded.json", "matrix_payload_..\\embedded.json",
                  "legacy.json", "matrix_payload_embedded.html"])
func matrixManifestRejectsUnsafeFixtureNames(name: String) throws {
    var row = matrixTestRow()
    row["analysisFixture"] = name
    #expect(throws: (any Error).self) { try matrixTestManifest(rows: [row]) }
}

@Test(arguments: [-1, 0, 2])
func matrixManifestRejectsInconsistentCounts(count: Int) throws {
    var row = matrixTestRow()
    var expected = row["expected"] as! [String: Any]
    expected["candidateCount"] = count
    row["expected"] = expected
    #expect(throws: (any Error).self) { try matrixTestManifest(rows: [row]) }
}

@Test(arguments: ["unavailableAllowed", "allowedWithoutURLs", "deniedWithURLs", "deniedWithLinks", "allowedWithBlock"])
func matrixManifestRejectsInconsistentEligibility(variant: String) throws {
    var row = matrixTestRow()
    var expected = row["expected"] as! [String: Any]
    switch variant {
    case "unavailableAllowed": expected["disposition"] = "unavailable"
    case "allowedWithoutURLs": expected["readerURLs"] = [] as [String]
    case "deniedWithURLs":
        expected["disposition"] = "unavailable"
        expected["readerAllowed"] = false
    case "deniedWithLinks":
        expected["disposition"] = "unavailable"
        expected["readerAllowed"] = false
        expected["readerURLs"] = [] as [String]
        expected["sessionNext"] = "https://reader.example.test/read/next"
    default: expected["requiredHardBlocks"] = ["paywall"]
    }
    row["expected"] = expected
    #expect(throws: (any Error).self) { try matrixTestManifest(rows: [row]) }
}

@Test(arguments: ["extractedPrevious", "extractedNext", "sessionPrevious", "sessionNext"])
func matrixManifestRequiresExplicitNullableLinks(key: String) throws {
    var row = matrixTestRow()
    var expected = row["expected"] as! [String: Any]
    expected.removeValue(forKey: key)
    row["expected"] = expected
    #expect(throws: (any Error).self) { try matrixTestManifest(rows: [row]) }
}

@Test(arguments: ["emptyID", "emptyEvidence", "noResource", "blankLimits", "payloadWithoutResource", "DOMWithoutResource"])
func matrixManifestRejectsIncompleteClassifications(variant: String) throws {
    var row = matrixTestRow()
    switch variant {
    case "emptyID": row["id"] = "  "
    case "emptyEvidence": row["evidence"] = [] as [String]
    case "noResource": row["analysisFixture"] = NSNull()
    case "blankLimits": row["limits"] = "  "
    case "payloadWithoutResource":
        row["analysisFixture"] = NSNull()
        row["htmlFixture"] = "matrix_dom_embedded.html"
    default: row["evidence"] = ["webKitDOM"]
    }
    #expect(throws: (any Error).self) { try matrixTestManifest(rows: [row]) }
}

@Test(arguments: ["capability", "coverage", "registry", "phase", "evidence", "parserPath", "disposition", "retry", "requiredHardBlocks"])
func matrixManifestRejectsUnknownEnums(key: String) throws {
    var row = matrixTestRow()
    if ["parserPath", "disposition", "retry", "requiredHardBlocks"].contains(key) {
        var expected = row["expected"] as! [String: Any]
        expected[key] = key == "requiredHardBlocks" ? ["unknown"] : "unknown"
        row["expected"] = expected
    } else {
        row[key] = key == "evidence" ? ["unknown"] : "unknown"
    }
    #expect(throws: (any Error).self) { try matrixTestManifest(rows: [row]) }
}

@Test func matrixManifestIsolatesLegacyResourcesAndDirectories() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    for name in ["matrix_payload_embedded.json", "matrix_dom_embedded.html", "legacy.json", "compatibility_matrix_v1.json", "matrix_payload_notes.txt"] {
        try Data("{}".utf8).write(to: directory.appendingPathComponent(name))
    }
    try FileManager.default.createDirectory(at: directory.appendingPathComponent("matrix_dom_directory.html"), withIntermediateDirectories: false)
    #expect(try matrixFixtureInventory(in: directory) == ["matrix_payload_embedded.json", "matrix_dom_embedded.html"])
}

@Test func matrixManifestAcceptsExplicitNullLinksAndSharedResources() throws {
    var second = matrixTestRow()
    second["id"] = "shared-payload"
    let rows = try matrixTestManifest(rows: [matrixTestRow(), second]).cases
    #expect(rows.count == 2)
    #expect(rows[0].expected.extractedPrevious == nil)
    try validateMatrixInventory(rows: rows, sourceFiles: ["matrix_payload_embedded.json"], bundledFiles: ["matrix_payload_embedded.json"])
}

private func matrixTestManifest(version: Int = 1, rows: [[String: Any]]? = nil) throws -> CompatibilityMatrixManifest {
    let payload: [String: Any] = ["schemaVersion": version, "cases": rows ?? [matrixTestRow()]]
    return try JSONDecoder().decode(CompatibilityMatrixManifest.self, from: JSONSerialization.data(withJSONObject: payload))
}

private func matrixTestRow() -> [String: Any] {
    [
        "id": "unknown-embedded", "capability": "embeddedHTML", "coverage": "covered",
        "analysisFixture": "matrix_payload_embedded.json", "htmlFixture": NSNull(),
        "registry": "default", "phase": "static", "variants": [] as [String],
        "evidence": ["payloadDecoding"], "limits": "Synthetic payload only; no DOM or remote delivery evidence.",
        "expected": [
            "parserPath": "genericHeuristic", "disposition": "automatic", "candidateCount": 1,
            "orderedCandidates": [["id": "panel-01", "url": "https://cdn.example.test/pages/01.jpg"]],
            "readerURLs": ["https://cdn.example.test/pages/01.jpg"],
            "extractedPrevious": NSNull(), "extractedNext": NSNull(),
            "sessionPrevious": NSNull(), "sessionNext": NSNull(),
            "readerAllowed": true, "requiredHardBlocks": [] as [String], "retry": "none"
        ] as [String: Any]
    ]
}

@Test func matrixManifestMatchesSourceAndBundledInventory() throws {
    let manifest = try loadMatrixManifest()
    #expect(manifest.schemaVersion == 1)
    #expect(!manifest.cases.isEmpty)
    try validateMatrixInventory(rows: manifest.cases, sourceFiles: matrixSourceFixtureInventory(),
                                bundledFiles: matrixBundledFixtureInventory())
}

@Test(arguments: try loadMatrixManifest().cases.filter { $0.analysisFixture != nil })
func matrixPayloadMatchesDeclaredOutcome(row: CompatibilityMatrixCase) throws {
    let page = try loadMatrixAnalysis(named: #require(row.analysisFixture))
    let result = matrixDetectorResult(page: page, row: row)
    let expected = row.expected
    #expect(result.pageURL == page.pageURL)
    #expect(result.diagnostics.parserPath == expected.parserPath)
    #expect(result.readerEntryDisposition == expected.disposition)
    #expect(result.candidates.count == expected.candidateCount)
    #expect(result.diagnostics.candidateCount == expected.candidateCount)
    #expect(matrixCandidateOrder(result) == expected.orderedCandidates)
    #expect(result.readerSession?.imageURLs.map(\.absoluteString) ?? [] == expected.readerURLs)
    #expect(page.previousChapterURL?.absoluteString == expected.extractedPrevious)
    #expect(page.nextChapterURL?.absoluteString == expected.extractedNext)
    #expect(result.readerSession?.previousChapter?.sourceURL.absoluteString == expected.sessionPrevious)
    #expect(result.readerSession?.nextChapter?.sourceURL.absoluteString == expected.sessionNext)
    #expect((result.readerSession != nil) == expected.readerAllowed)
    #expect(Set(expected.requiredHardBlocks).isSubset(of: result.diagnostics.hardBlocks))
    #expect(result.retryRecommendation == expected.retry)
    #expect(result.diagnostics.retryRecommendation == expected.retry)
    if let session = result.readerSession { #expect(session.sourceURL == page.pageURL) }
    if row.id == "recommended" { #expect(result.score == 58) }
    if row.id == "manual" { #expect(result.score == 46) }
    if row.registry == .default || row.registry == .empty {
        #expect(result.diagnostics.profileDomain == nil)
    } else {
        #expect(result.diagnostics.profileDomain == page.pageURL.host())
    }
    switch row.capability {
    case .challenge, .authentication, .paywall, .errorPage, .protectedViewer,
         .canvasOrBlob, .unsupportedPagination, .browserOnly:
        #expect(row.coverage == .unsupportedByPolicy)
        #expect(!row.expected.readerAllowed)
        #expect(!row.expected.requiredHardBlocks.isEmpty)
    case .hydratedDOM, .browserSession, .requestContext:
        #expect(row.coverage == .partial)
    case .imageDelivery:
        #expect(row.coverage == (row.id == "srcset" ? .partial : .covered))
    case .embeddedHTML, .negativeDecorative:
        #expect(row.coverage == .covered)
    }
    #expect(row.evidence.contains(.payloadDecoding))
    #expect(row.evidence.contains(.browserModel))
}

@MainActor
@Test(arguments: try loadMatrixManifest().cases.filter { $0.analysisFixture != nil })
func matrixBrowserMatchesDeclaredDisposition(row: CompatibilityMatrixCase) throws {
    let page = try loadMatrixAnalysis(named: #require(row.analysisFixture))
    let result = matrixDetectorResult(page: page, row: row)
    let model = BrowserViewModel(startPoint: .url(page.pageURL.absoluteString))
    #expect(model.currentURL == page.pageURL)
    model.updateNavigation(url: page.pageURL, title: page.title, canGoBack: true,
                           canGoForward: false, isLoading: false)
    model.handleDetectionResult(result)
    #expect(model.detectionResult?.readerEntryDisposition == row.expected.disposition)
    #expect(model.browserOwnedReaderSession == nil)
    switch row.expected.disposition {
    case .automatic:
        #expect(model.cleanModePresentation == .hidden)
        #expect(model.pendingReaderSession != nil)
        #expect(!model.showsCleanModeCTA)
    case .recommended, .manual:
        #expect(model.cleanModePresentation == (row.expected.disposition == .recommended ? .recommendedBanner : .manualTool))
        #expect(model.showsCleanModeCTA == (row.expected.disposition == .recommended))
        #expect(model.pendingReaderSession == nil)
        model.enterCleanModeManually()
        #expect(model.pendingReaderSession != nil)
        #expect(model.cleanModePresentation == .hidden)
    case .unavailable:
        #expect(model.cleanModePresentation == .hidden)
        #expect(!model.showsCleanModeCTA)
        #expect(model.pendingReaderSession == nil)
        model.enterCleanModeManually()
        #expect(model.pendingReaderSession == nil)
        #expect(model.browserOwnedReaderSession == nil)
    }
    if row.expected.readerAllowed {
        let session = try #require(model.pendingReaderSession)
        #expect(session.sourceURL == page.pageURL)
        #expect(session.imageURLs.map(\.absoluteString) == row.expected.readerURLs)
        model.presentPendingReaderInsideBrowser(session)
        #expect(model.pendingReaderSession == nil)
        #expect(model.browserOwnedReaderSession == session)
        #expect(model.readerPresentationState == .browserOwnedReaderVisible)
        #expect(model.currentURL == page.pageURL)
        #expect(model.canGoBack && !model.canGoForward)
        model.dismissBrowserOwnedReader()
        #expect(model.browserOwnedReaderSession == nil)
        #expect(model.readerPresentationState == .none)
        #expect(session.imageURLs.map(\.absoluteString) == row.expected.readerURLs)
        #expect(model.detectionResult?.readerSession?.imageURLs.map(\.absoluteString) == row.expected.readerURLs)
        #expect(model.currentURL == page.pageURL)
        #expect(model.canGoBack && !model.canGoForward)
        // Repopulate pending eligibility before navigation to prove stale sessions clear.
        model.handleDetectionResult(result)
        if row.expected.disposition != .automatic { model.enterCleanModeManually() }
        #expect(model.pendingReaderSession != nil)
    }
    model.navigationDidStart()
    #expect(model.detectionResult == nil)
    #expect(model.pendingReaderSession == nil)
    #expect(model.cleanModePresentation == .hidden)
    model.enterCleanModeManually()
    #expect(model.pendingReaderSession == nil)
}

@Test(arguments: try loadMatrixManifest().cases.filter {
    $0.analysisFixture != nil && $0.registry == .default && $0.expected.readerAllowed
})
func matrixUnknownDomainUsesGenericRouting(row: CompatibilityMatrixCase) throws {
    let page = try loadMatrixAnalysis(named: #require(row.analysisFixture))
    #expect(SiteProfileRegistry.default.profile(for: page.pageURL) == nil)
    let defaultResult = ProfileAwareChapterDetector().detect(page: page)
    let emptyResult = ProfileAwareChapterDetector(registry: SiteProfileRegistry(profiles: [])).detect(page: page)
    for result in [defaultResult, emptyResult] {
        #expect(result.diagnostics.parserPath == .genericHeuristic)
        #expect(result.diagnostics.profileDomain == nil)
        #expect(matrixCandidateOrder(result) == row.expected.orderedCandidates)
        #expect(result.readerSession?.imageURLs.map(\.absoluteString) ?? [] == row.expected.readerURLs)
        #expect(result.readerEntryDisposition == row.expected.disposition)
        #expect(result.readerSession?.sourceURL == page.pageURL)
        #expect(result.readerSession?.previousChapter?.sourceURL.absoluteString == row.expected.sessionPrevious)
        #expect(result.readerSession?.nextChapter?.sourceURL.absoluteString == row.expected.sessionNext)
    }
    // Session/chapter identities are freshly generated; compare the declared outcome and stable detector evidence.
    #expect(defaultResult.candidates == emptyResult.candidates)
    #expect(defaultResult.diagnostics == emptyResult.diagnostics)
}

@Test(arguments: try loadMatrixManifest().cases.filter {
    $0.phase == .beforeHydration || $0.phase == .afterHydration ||
    $0.phase == .profileInitial || $0.phase == .profileFollowUp
})
func matrixHydrationRetryEvidenceIsBounded(row: CompatibilityMatrixCase) throws {
    let page = try loadMatrixAnalysis(named: #require(row.analysisFixture))
    let result = matrixDetectorResult(page: page, row: row)
    #expect(result.retryRecommendation == row.expected.retry)
    #expect(row.coverage == .partial)
    #expect(row.evidence.contains(.retryPolicy))
    var policy = BrowserDetectionRetryPolicy()
    let schedules = policy.shouldScheduleFollowUp(for: page.pageURL, recommendation: result.retryRecommendation,
                                                 confidence: result.confidence)
    #expect(schedules == (row.expected.retry == .browserSessionFollowUp))
    let schedulesAgain = policy.shouldScheduleFollowUp(for: page.pageURL, recommendation: result.retryRecommendation,
                                                       confidence: result.confidence)
    #expect(!schedulesAgain)
}

private func matrixCandidateOrder(_ result: DetectionResult) -> [MatrixCandidateExpectation] {
    result.candidates.map { MatrixCandidateExpectation(id: $0.id ?? "", url: $0.src ?? "") }
}

func matrixDetectorResult(page: DetectionPageAnalysis, row: CompatibilityMatrixCase) -> DetectionResult {
    let registry: SiteProfileRegistry
    switch row.registry {
    case .default: registry = .default
    case .empty: registry = SiteProfileRegistry(profiles: [])
    case .syntheticBrowserSession, .syntheticPaginated, .syntheticBrowserOnly:
        let template: SiteProfileTemplate = row.registry == .syntheticBrowserSession ? .browserSession
            : row.registry == .syntheticPaginated ? .paginatedSinglePage : .browserOnly
        let tier: SiteProfileSupportTier = row.registry == .syntheticBrowserOnly ? .browserOnly : .approvedNonPromoted
        registry = SiteProfileRegistry(profiles: [SiteProfile(domain: page.pageURL.host() ?? "invalid.example.test",
                                                             supportTier: tier, template: template)])
    }
    let detector = ProfileAwareChapterDetector(registry: registry)
    // Initial profile detection and its explicitly requested follow-up are different APIs.
    return row.phase == .profileFollowUp ? detector.detectBrowserSessionFollowUp(page: page) : detector.detect(page: page)
}
