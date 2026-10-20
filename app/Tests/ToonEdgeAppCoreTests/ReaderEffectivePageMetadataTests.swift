import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore
struct ReaderEffectivePageMetadataTests {
    @Test func invalidDeclaredDimensionsBecomePlaceholderThenValidDecodedGeometry() throws {
        let size = CGSize(width: 300, height: 500)
        let session = UUID()
        for value in [0.0, -1, Double.nan, Double.infinity] {
            let declared = ReaderPageMetadata(pixelWidth: value, pixelHeight: 900)
            let placeholderMetadata = ReaderEffectivePageMetadata.resolve(learned: nil, declared: declared)
            #expect(placeholderMetadata == nil)
            let placeholder = try #require(ReaderFittedLayout(sessionID: session, revision: 0,
                viewportSize: size, displayMode: .fitWidth, pageSpacing: 0, metadata: [placeholderMetadata]))
            #expect(placeholder.geometry.pageFrames[0].height == 430)
            let decoded = ReaderPageMetadata(pixelWidth: 300, pixelHeight: 900)
            let effective = ReaderEffectivePageMetadata.resolve(learned: decoded, declared: declared)
            #expect(effective == decoded)
            let learned = try #require(ReaderFittedLayout(sessionID: session, revision: 1,
                viewportSize: size, displayMode: .fitWidth, pageSpacing: 0, metadata: [effective]))
            #expect(learned.geometry.pageFrames[0].height == 900)
        }
        let invalidHeight = ReaderPageMetadata(pixelWidth: 300, pixelHeight: 0)
        #expect(ReaderEffectivePageMetadata.resolve(learned: nil, declared: invalidHeight) == nil)
    }
    @Test func validLearnedDimensionsWinAndInvalidLearnedDimensionsFallBack() {
        let declared = ReaderPageMetadata(pixelWidth: 300, pixelHeight: 500)
        let decoded = ReaderPageMetadata(pixelWidth: 300, pixelHeight: 900)
        #expect(ReaderEffectivePageMetadata.resolve(learned: decoded, declared: declared) == decoded)
        let invalid = ReaderPageMetadata(pixelWidth: 0, pixelHeight: .infinity)
        #expect(ReaderEffectivePageMetadata.resolve(learned: invalid, declared: declared) == declared)
        #expect(ReaderEffectivePageMetadata.resolve(learned: invalid, declared: nil) == nil)
    }
}
