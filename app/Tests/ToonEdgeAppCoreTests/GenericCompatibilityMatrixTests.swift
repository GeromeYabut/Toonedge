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

@Test(arguments: try loadMatrixManifest().cases.filter {
    $0.analysisFixture != nil && $0.registry == .default && $0.phase == .static
})
func matrixPayloadMatchesDeclaredProductionOutcome(row: CompatibilityMatrixCase) throws {
    let name = try #require(row.analysisFixture)
    let page = try loadMatrixAnalysis(named: name)
    #expect(SiteProfileRegistry.default.profile(for: page.pageURL) == nil)
    let result = ProfileAwareChapterDetector().detect(page: page)
    let expected = row.expected
    #expect(result.diagnostics.parserPath == expected.parserPath)
    #expect(result.readerEntryDisposition == expected.disposition)
    #expect(result.candidates.count == expected.candidateCount)
    #expect(result.candidates.map { MatrixCandidateExpectation(id: $0.id ?? "", url: $0.src ?? "") }
            == expected.orderedCandidates)
    #expect(result.readerSession?.imageURLs.map(\.absoluteString) ?? [] == expected.readerURLs)
    #expect(page.previousChapterURL?.absoluteString == expected.extractedPrevious)
    #expect(page.nextChapterURL?.absoluteString == expected.extractedNext)
    #expect(result.readerSession?.previousChapter?.sourceURL.absoluteString == expected.sessionPrevious)
    #expect(result.readerSession?.nextChapter?.sourceURL.absoluteString == expected.sessionNext)
    #expect((result.readerSession != nil) == expected.readerAllowed)
    #expect(Set(expected.requiredHardBlocks).isSubset(of: result.diagnostics.hardBlocks))
    #expect(result.retryRecommendation == expected.retry)
    if let session = result.readerSession { #expect(session.sourceURL == page.pageURL) }
}
