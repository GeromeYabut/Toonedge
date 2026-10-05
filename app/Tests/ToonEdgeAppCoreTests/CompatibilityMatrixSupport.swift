import Foundation
@testable import ToonEdgeAppCore

struct CompatibilityMatrixManifest: Decodable, Sendable {
    let schemaVersion: Int
    let cases: [CompatibilityMatrixCase]

    private enum CodingKeys: String, CodingKey { case schemaVersion, cases }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        cases = try values.decode([CompatibilityMatrixCase].self, forKey: .cases)
        guard schemaVersion == 1 else {
            throw MatrixValidationError.invalidManifest("Unsupported schema version: \(schemaVersion)")
        }
        try validateMatrixRows(cases)
    }
}

struct CompatibilityMatrixCase: Decodable, Sendable {
    let id: String
    let capability: MatrixCapability
    let coverage: MatrixCoverage
    let analysisFixture: String?
    let htmlFixture: String?
    let registry: MatrixRegistry
    let phase: MatrixPhase
    let variants: [String]
    let expected: MatrixExpectation
    let evidence: [MatrixEvidence]
    let limits: String
}

enum MatrixCapability: String, Decodable, Sendable {
    case embeddedHTML, hydratedDOM, browserSession, imageDelivery, requestContext, negativeDecorative
    case challenge, authentication, paywall, errorPage, protectedViewer, canvasOrBlob
    case unsupportedPagination, browserOnly
}

enum MatrixCoverage: String, Decodable, Sendable {
    case covered, partial
    case unsupportedByPolicy = "unsupported-by-policy"
}

enum MatrixRegistry: String, Decodable, Sendable {
    case `default`, empty, syntheticBrowserSession, syntheticPaginated, syntheticBrowserOnly
}

enum MatrixPhase: String, Decodable, Sendable {
    case `static`, beforeHydration, afterHydration, profileInitial, profileFollowUp
}

enum MatrixEvidence: String, Decodable, Sendable {
    case payloadDecoding, webKitDOM, browserModel, requestHeaders, retryPolicy
}

struct MatrixCandidateExpectation: Decodable, Equatable, Sendable {
    let id: String
    let url: String
}

struct MatrixExpectation: Decodable, Sendable {
    let parserPath: DetectionParserPath
    let disposition: ReaderEntryDisposition
    let candidateCount: Int
    let orderedCandidates: [MatrixCandidateExpectation]
    let readerURLs: [String]
    let extractedPrevious: String?
    let extractedNext: String?
    let sessionPrevious: String?
    let sessionNext: String?
    let readerAllowed: Bool
    let requiredHardBlocks: [DetectionHardBlock]
    let retry: DetectionRetryRecommendation

    private enum CodingKeys: String, CodingKey {
        case parserPath, disposition, candidateCount, orderedCandidates, readerURLs
        case extractedPrevious, extractedNext, sessionPrevious, sessionNext
        case readerAllowed, requiredHardBlocks, retry
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        parserPath = try values.decode(DetectionParserPath.self, forKey: .parserPath)
        disposition = try values.decode(ReaderEntryDisposition.self, forKey: .disposition)
        candidateCount = try values.decode(Int.self, forKey: .candidateCount)
        orderedCandidates = try values.decode([MatrixCandidateExpectation].self, forKey: .orderedCandidates)
        readerURLs = try values.decode([String].self, forKey: .readerURLs)
        // decode(Optional.self) requires the key while still accepting explicit JSON null.
        extractedPrevious = try values.decode(String?.self, forKey: .extractedPrevious)
        extractedNext = try values.decode(String?.self, forKey: .extractedNext)
        sessionPrevious = try values.decode(String?.self, forKey: .sessionPrevious)
        sessionNext = try values.decode(String?.self, forKey: .sessionNext)
        readerAllowed = try values.decode(Bool.self, forKey: .readerAllowed)
        requiredHardBlocks = try values.decode([DetectionHardBlock].self, forKey: .requiredHardBlocks)
        retry = try values.decode(DetectionRetryRecommendation.self, forKey: .retry)
    }
}

enum MatrixValidationError: Error {
    case invalidManifest(String)
    case inventoryMismatch(kind: String, missing: Set<String>, unclassified: Set<String>)
    case missingResource(String)
}

private func validateMatrixRows(_ rows: [CompatibilityMatrixCase]) throws {
    var ids = Set<String>()
    for row in rows {
        guard !row.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              ids.insert(row.id).inserted else {
            throw MatrixValidationError.invalidManifest("Empty or duplicate case ID: \(row.id)")
        }
        guard row.analysisFixture != nil || row.htmlFixture != nil,
              !row.evidence.isEmpty,
              !row.limits.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MatrixValidationError.invalidManifest("Incomplete classification: \(row.id)")
        }
        if let name = row.analysisFixture {
            try validateMatrixFixtureName(name, prefix: "matrix_payload_", extension: "json")
        }
        if let name = row.htmlFixture {
            try validateMatrixFixtureName(name, prefix: "matrix_dom_", extension: "html")
        }
        guard !row.evidence.contains(.payloadDecoding) || row.analysisFixture != nil,
              !row.evidence.contains(.webKitDOM) || row.htmlFixture != nil else {
            throw MatrixValidationError.invalidManifest("Evidence lacks its required resource: \(row.id)")
        }
        let expected = row.expected
        guard expected.candidateCount >= 0,
              expected.candidateCount == expected.orderedCandidates.count else {
            throw MatrixValidationError.invalidManifest("Inconsistent candidate count: \(row.id)")
        }
        guard expected.readerAllowed == (expected.disposition != .unavailable),
              expected.readerAllowed == !expected.readerURLs.isEmpty else {
            throw MatrixValidationError.invalidManifest("Inconsistent Reader eligibility: \(row.id)")
        }
        if expected.readerAllowed {
            guard expected.requiredHardBlocks.isEmpty,
                  expected.readerURLs == expected.orderedCandidates.map(\.url) else {
                throw MatrixValidationError.invalidManifest("Inconsistent eligible Reader outcome: \(row.id)")
            }
        } else if expected.sessionPrevious != nil || expected.sessionNext != nil {
            throw MatrixValidationError.invalidManifest("Ineligible Reader has session links: \(row.id)")
        }
    }
}

private func validateMatrixFixtureName(_ name: String, prefix: String, extension fileExtension: String) throws {
    guard name.hasPrefix(prefix), name.hasSuffix(".\(fileExtension)"),
          name.count > prefix.count + fileExtension.count + 1,
          !name.contains("/"), !name.contains("\\"), !name.contains("..") else {
        throw MatrixValidationError.invalidManifest("Invalid matrix fixture basename: \(name)")
    }
}

func validateMatrixInventory(
    rows: [CompatibilityMatrixCase], sourceFiles: Set<String>, bundledFiles: Set<String>
) throws {
    try validateMatrixRows(rows)
    let referencedFiles = Set(rows.flatMap { [$0.analysisFixture, $0.htmlFixture].compactMap { $0 } })
    for (kind, files) in [("source", sourceFiles), ("bundle", bundledFiles)] {
        guard files == referencedFiles else {
            throw MatrixValidationError.inventoryMismatch(
                kind: kind, missing: referencedFiles.subtracting(files),
                unclassified: files.subtracting(referencedFiles)
            )
        }
    }
}

/// Only the explicit matrix resources participate; legacy fixtures and directories are excluded.
func matrixFixtureInventory(in directory: URL) throws -> Set<String> {
    let files = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]
    )
    return Set(try files.filter { file in
        let name = file.lastPathComponent
        guard (name.hasPrefix("matrix_payload_") && name.hasSuffix(".json"))
                || (name.hasPrefix("matrix_dom_") && name.hasSuffix(".html")) else { return false }
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        return values.isRegularFile == true && values.isSymbolicLink != true
    }.map(\.lastPathComponent))
}

func matrixSourceFixtureInventory() throws -> Set<String> {
    try matrixFixtureInventory(in: URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().appendingPathComponent("Fixtures", isDirectory: true))
}

func matrixBundledFixtureInventory() throws -> Set<String> {
    guard let directory = Bundle.module.resourceURL else {
        throw MatrixValidationError.missingResource("Bundle resource directory")
    }
    return try matrixFixtureInventory(in: directory)
}

func loadMatrixManifest() throws -> CompatibilityMatrixManifest {
    guard let url = Bundle.module.url(forResource: "compatibility_matrix_v1", withExtension: "json") else {
        throw MatrixValidationError.missingResource("compatibility_matrix_v1.json")
    }
    return try JSONDecoder().decode(CompatibilityMatrixManifest.self, from: Data(contentsOf: url))
}

func loadMatrixAnalysis(named name: String) throws -> DetectionPageAnalysis {
    // Validate the resource path independently; analysis uses the unmodified production decoder.
    try validateMatrixFixtureName(name, prefix: "matrix_payload_", extension: "json")
    let basename = String(name.dropLast(".json".count))
    guard let url = Bundle.module.url(forResource: basename, withExtension: "json") else {
        throw MatrixValidationError.missingResource(name)
    }
    return try JSONDecoder().decode(DetectionPageAnalysis.self, from: Data(contentsOf: url))
}
