import Foundation
import Testing
@testable import ToonEdgeAppCore

private let matrixDOMOrigin = URL(string: "https://unknown-reader.example.test/read/arrival")!
private let matrixLazyAttributes = ["data-src", "data-original", "data-lazy-src", "data-lazy", "data-url", "data-image", "data-full", "data-full-src", "data-actualsrc"]
private let matrixSrcsetAttributes = ["srcset", "data-srcset", "data-lazy-srcset"]

struct MatrixDOMVariant: Sendable, CustomTestStringConvertible {
    let row: CompatibilityMatrixCase
    let attribute: String
    let sanitize: Bool
    var testDescription: String { "\(row.id)/\(attribute)/sanitize=\(sanitize)" }
}

private func matrixDOMVariants() throws -> [MatrixDOMVariant] {
    try loadMatrixManifest().cases.filter { $0.htmlFixture != nil }.flatMap { row in
        (row.variants.isEmpty ? ["default"] : row.variants).flatMap { attribute in
            [false, true].map { MatrixDOMVariant(row: row, attribute: attribute, sanitize: $0) }
        }
    }
}

@Suite(.serialized)
@MainActor
struct CompatibilityDOMExtractionTests {
    @Test(arguments: try matrixDOMVariants())
    func matrixDOMMatchesDeclaredExtraction(variant: MatrixDOMVariant) async throws {
        let row = variant.row
        let html = try matrixHTML(row: row, attribute: variant.attribute)
        let harness = MatrixWebKitHarness()
        let page = try await harness.analyze(html: html, pageURL: matrixDOMOrigin,
                                             sanitize: variant.sanitize, phase: row.phase)
        assertMatrixDOMOutcome(page: page, row: row)
        #expect(harness.navigationPolicyDecisionCount > 0)
        #expect(harness.externalResourceByteCount == 0)
        #expect(page.viewportWidth == 390 && page.viewportHeight == 844)
        #expect(page.images.allSatisfy { $0.width.isFinite && $0.height.isFinite && $0.top.isFinite && $0.left.isFinite })
        let panels = page.images.filter { $0.id?.hasPrefix("panel-") == true }
        if row.expected.candidateCount > 0 && row.id != "dom-opaque-blob" {
            #expect(panels.allSatisfy { $0.width == 390 && $0.height == 1350 && $0.renderedHeight == 1350 })
            #expect(zip(panels, panels.dropFirst()).allSatisfy { $0.top < $1.top })
        }
        if row.id == "dom-lazy" {
            #expect(matrixLazyAttributes.contains(variant.attribute))
            #expect(panels.map(\.lazySources) == (1...6).map { ["https://cdn.example.test/pages/\(String(format: "%02d", $0)).jpg"] })
            #expect(harness.rawSourceAttributes == Array(repeating: "blank.gif", count: 6))
            #expect(panels.allSatisfy { $0.semanticHints.contains("data-reader-page-image") && $0.semanticHints.contains("data-reader-index") })
        }
        if row.id == "dom-srcset" {
            #expect(matrixSrcsetAttributes.contains(variant.attribute))
            #expect(panels.map(\.srcset) == (1...6).map {
                let index = String(format: "%02d", $0)
                return "https://cdn.example.test/pages/\(index).jpg 1x, https://cdn.example.test/large/\(index).jpg 2x"
            })
            #expect(harness.rawSourceAttributes == Array(repeating: "blank.gif", count: 6))
        }
        if row.id == "dom-url-forms" {
            #expect(harness.rawSourceAttributes == ["https://cdn.example.test/pages/01.jpg", "/pages/02.jpg", "pages/03.jpg", "../pages/04.jpg", "//cdn.example.test/pages/05.jpg", "  https://cdn.example.test/pages/06.jpg  "])
        }
        if row.htmlFixture == "matrix_dom_gates.html" {
            #expect(panels.count == 6)
            #expect(panels.map(\.id) == (1...6).map { "panel-\(String(format: "%02d", $0))" })
            #expect(panels.allSatisfy { $0.width == 390 && $0.height == 1350 && $0.renderedHeight == 1350 })
        }
        if row.htmlFixture == "matrix_dom_gates.html" || row.id == "dom-ads-reader" || row.id == "dom-ad-only" {
            let noise = try #require(page.images.first { $0.id == "advert-noise" })
            #expect(noise.renderedHeight == (variant.sanitize ? 0 : 600))
        }
        if row.id == "dom-gate-hidden" || row.id == "dom-small-canvas" {
            #expect(page.hardBlocks.isEmpty)
        }
        if row.id == "pagination-dom-unclassified" {
            #expect(!page.hardBlocks.contains(.unsupportedPagination))
            #expect(!matrixDetectorResult(page: page, row: row).diagnostics.hardBlocks.contains(.unsupportedPagination))
            #expect(row.coverage == .partial)
        }
        #expect(row.evidence.contains(.webKitDOM))
    }

    @Test(arguments: [false, true])
    func matrixDOMHydrationPreservesOriginAndOrder(sanitize: Bool) async throws {
        let rows = try loadMatrixManifest().cases
        let beforeRow = try #require(rows.first { $0.id == "dom-hydration-before" })
        let afterRow = try #require(rows.first { $0.id == "dom-hydration-after" })
        let harness = MatrixWebKitHarness()
        let (before, after) = try await harness.analyzeHydration(html: matrixHTML(row: beforeRow, attribute: "default"),
                                                               pageURL: matrixDOMOrigin, sanitize: sanitize)
        assertMatrixDOMOutcome(page: before, row: beforeRow)
        assertMatrixDOMOutcome(page: after, row: afterRow)
        #expect(before.pageURL == after.pageURL && after.pageURL == matrixDOMOrigin)
        #expect(before.images.isEmpty)
        #expect(after.images.map(\.id) == (1...6).map { "panel-\(String(format: "%02d", $0))" })
        #expect(after.images.allSatisfy { $0.renderedHeight == 1350 })
        #expect(harness.navigationPolicyDecisionCount > 0)
        #expect(harness.externalResourceByteCount == 0)
        #expect(matrixDetectorResult(page: before, row: beforeRow).retryRecommendation == .none)
        #expect(matrixDetectorResult(page: after, row: afterRow).retryRecommendation == .none)
    }

    @Test func matrixDOMVariantInventoryIsExplicit() throws {
        let variants = try matrixDOMVariants()
        #expect(variants.count == 58)
        #expect(Set(variants.map { $0.row.id }).count == 19)
        #expect(Set(variants.filter { $0.row.id == "dom-lazy" }.map(\.attribute)) == Set(matrixLazyAttributes))
        #expect(Set(variants.filter { $0.row.id == "dom-srcset" }.map(\.attribute)) == Set(matrixSrcsetAttributes))
        #expect(Set(variants.compactMap { $0.row.htmlFixture }).count == 9)
    }
}

@MainActor
private func assertMatrixDOMOutcome(page: DetectionPageAnalysis, row: CompatibilityMatrixCase) {
    let result = matrixDetectorResult(page: page, row: row)
    let expected = row.expected
    #expect(page.pageURL == matrixDOMOrigin)
    #expect(result.diagnostics.parserPath == expected.parserPath)
    #expect(result.diagnostics.profileDomain == nil)
    #expect(result.readerEntryDisposition == expected.disposition)
    #expect(result.candidates.count == expected.candidateCount)
    #expect(result.diagnostics.candidateCount == expected.candidateCount)
    #expect(result.candidates.map { MatrixCandidateExpectation(id: $0.id ?? "", url: $0.src ?? "") } == expected.orderedCandidates)
    #expect(result.readerSession?.imageURLs.map(\.absoluteString) ?? [] == expected.readerURLs)
    #expect(page.previousChapterURL?.absoluteString == expected.extractedPrevious)
    #expect(page.nextChapterURL?.absoluteString == expected.extractedNext)
    #expect(result.readerSession?.previousChapter?.sourceURL.absoluteString == expected.sessionPrevious)
    #expect(result.readerSession?.nextChapter?.sourceURL.absoluteString == expected.sessionNext)
    #expect((result.readerSession != nil) == expected.readerAllowed)
    #expect(Set(expected.requiredHardBlocks).isSubset(of: Set(page.hardBlocks)))
    #expect(Set(expected.requiredHardBlocks).isSubset(of: result.diagnostics.hardBlocks))
    #expect(result.retryRecommendation == expected.retry)
    if let session = result.readerSession { #expect(session.sourceURL == page.pageURL) }
}

private func matrixHTML(row: CompatibilityMatrixCase, attribute: String) throws -> String {
    let name = try #require(row.htmlFixture)
    guard let url = Bundle.module.url(forResource: String(name.dropLast(".html".count)), withExtension: "html") else {
        throw MatrixValidationError.missingResource(name)
    }
    var html = try String(contentsOf: url, encoding: .utf8)
    if name == "matrix_dom_lazy.html" || name == "matrix_dom_srcset.html" {
        guard (matrixLazyAttributes + matrixSrcsetAttributes).contains(attribute) else {
            throw MatrixValidationError.invalidManifest("Unknown DOM source attribute")
        }
        html = html.replacingOccurrences(of: "{{ATTRIBUTE}}", with: attribute)
    }
    let panels = (1...6).map { index in
        let id = String(format: "%02d", index)
        return "<img id=\"panel-\(id)\" data-reader-page-image data-reader-index=\"\(index)\" src=\"https://cdn.example.test/pages/\(id).jpg\">"
    }.joined()
    let noise = "<aside id=\"sponsor-noise\"><img id=\"advert-noise\" class=\"noise advert\" src=\"https://cdn.example.test/ads/banner.jpg\"></aside>"
    if name == "matrix_dom_decorative.html" {
        let content: String
        switch attribute {
        case "thumbnails": content = "<main>" + (1...6).map { "<img class=\"thumb thumbnail\" src=\"https://cdn.example.test/thumb/\($0).jpg\">" }.joined() + "</main>"
        case "ad-only": content = noise
        case "ads-reader": content = noise + "<main class=\"chapter-content\">\(panels)</main>"
        default: throw MatrixValidationError.invalidManifest("Unknown decorative variant")
        }
        html = html.replacingOccurrences(of: "{{CONTENT}}", with: content)
    }
    if name == "matrix_dom_gates.html" {
        let gate: String
        switch attribute {
        case "authentication": gate = "<section class=\"gate auth-required\" role=\"dialog\"><span class=\"advert-copy\">Sign in to read</span></section>"
        case "paywall": gate = "<section class=\"gate paywall\" role=\"dialog\"><span class=\"advert-copy\">This chapter is locked. Subscribe to read</span></section>"
        case "challenge": gate = "<section class=\"gate reader-gate\" role=\"dialog\"><span class=\"advert-copy\">Enable JavaScript and cookies to continue</span></section>"
        case "error": gate = "<section class=\"gate error-page\"><span class=\"advert-copy\">404 page not found</span></section>"
        case "protected": gate = "<section class=\"gate protected-reader\" data-protected-reader=\"true\">Protected invented viewer</section>"
        case "hidden-authentication": gate = "<section hidden class=\"gate auth-required\" role=\"dialog\">Sign in to read</section>"
        default: throw MatrixValidationError.invalidManifest("Unknown gate variant")
        }
        html = html.replacingOccurrences(of: "{{GATE}}", with: gate)
    }
    if name == "matrix_dom_opaque.html" {
        let content: String
        switch attribute {
        case "canvas": content = "<canvas width=\"390\" height=\"1350\"></canvas>"
        case "blob": content = "<img id=\"opaque-panel\" src=\"blob:https://unknown-reader.example.test/invented-viewer\">"
        case "small-canvas": content = "<canvas width=\"30\" height=\"30\"></canvas>" + panels
        default: throw MatrixValidationError.invalidManifest("Unknown opaque variant")
        }
        html = html.replacingOccurrences(of: "{{CONTENT}}", with: content)
    }
    guard !html.contains("{{") else { throw MatrixValidationError.invalidManifest("Unexpanded HTML variant") }
    return html
}
