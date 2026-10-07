import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore

struct ReaderFittedLayoutTests {
    @Test func fitWidthPreservesAspectOrderAndEndSpacing() throws {
        let id = UUID()
        let layout = try #require(ReaderFittedLayout(
            sessionID: id, revision: 7, viewportSize: CGSize(width: 200, height: 100),
            displayMode: .fitWidth, pageSpacing: 8,
            metadata: [ReaderPageMetadata(pixelWidth: 200, pixelHeight: 400),
                       ReaderPageMetadata(pixelWidth: 100, pixelHeight: 100)]
        ))
        #expect(layout.geometry.sessionID == id)
        #expect(layout.geometry.revision == 7)
        #expect(layout.geometry.pageFrames == [CGRect(x: 0, y: 8, width: 200, height: 400),
                                               CGRect(x: 0, y: 416, width: 200, height: 200)])
        #expect(layout.contentSize == CGSize(width: 200, height: 624))
        #expect(layout.unresolvedPageIndexes.isEmpty)
    }

    @Test func fitScreenKeepsCurrentWidthInsetRatherThanHeightContainment() throws {
        let layout = try #require(ReaderFittedLayout(
            sessionID: UUID(), revision: 1, viewportSize: CGSize(width: 400, height: 300),
            displayMode: .fitScreen, pageSpacing: 0,
            metadata: [ReaderPageMetadata(pixelWidth: 200, pixelHeight: 400)]
        ))
        let frame = try #require(layout.geometry.pageFrames.first)
        #expect(abs(frame.width - 368) < 1e-8)
        #expect(abs(frame.minX - 16) < 1e-8)
        #expect(abs(frame.height - 736) < 1e-8)
        #expect(frame.height > layout.viewportSize.height)
    }

    @Test func missingMetadataIsExplicitlyProvisionalAndRevisable() throws {
        let id = UUID()
        let metadata: [ReaderPageMetadata?] = [nil, ReaderPageMetadata(pixelWidth: 200, pixelHeight: 100)]
        let provisional = try #require(ReaderFittedLayout(
            sessionID: id, revision: 1, viewportSize: CGSize(width: 200, height: 800),
            displayMode: .fitWidth, pageSpacing: 8, metadata: metadata
        ))
        #expect(provisional.unresolvedPageIndexes == [0])
        #expect(provisional.geometry.pageFrames[0].height == 430)
        #expect(provisional.geometry.pageFrames[1].minY == 446)
        let custom = try #require(ReaderFittedLayout(
            sessionID: id, revision: 1, viewportSize: CGSize(width: 200, height: 800),
            displayMode: .fitWidth, pageSpacing: 0, metadata: [nil], placeholderHeight: 200
        ))
        #expect(custom.geometry.pageFrames[0].height == 200)
        #expect(custom.unresolvedPageIndexes == [0])
        let resolved = try #require(ReaderFittedLayout(
            sessionID: id, revision: 2, viewportSize: CGSize(width: 200, height: 800),
            displayMode: .fitWidth, pageSpacing: 8,
            metadata: [ReaderPageMetadata(pixelWidth: 200, pixelHeight: 100), metadata[1]]
        ))
        #expect(resolved.unresolvedPageIndexes.isEmpty)
        #expect(resolved.geometry.pageFrames[1].minY == 116)
        #expect(provisional.geometry.revision == 1)
        #expect(resolved.geometry.revision == 2)
    }

    @Test func shortAndEmptyChaptersKeepViewportSizedCanvas() throws {
        let chapters: [[ReaderPageMetadata?]] = [[], [ReaderPageMetadata(pixelWidth: 200, pixelHeight: 100)]]
        for metadata in chapters {
            let layout = try #require(ReaderFittedLayout(
                sessionID: UUID(), revision: 0, viewportSize: CGSize(width: 200, height: 200),
                displayMode: .fitWidth, pageSpacing: 0, metadata: metadata
            ))
            #expect(layout.contentSize == CGSize(width: 200, height: 200))
            #expect(layout.geometry.pageFrames.count == metadata.count)
        }
    }

    @Test func invalidViewportSpacingAndPlaceholderAreRejected() {
        let id = UUID()
        for size in [CGSize.zero, CGSize(width: -1, height: 100),
                     CGSize(width: 100, height: CGFloat.nan), CGSize(width: CGFloat.infinity, height: 100)] {
            #expect(ReaderFittedLayout(sessionID: id, revision: 0, viewportSize: size,
                displayMode: .fitWidth, pageSpacing: 0, metadata: []) == nil)
        }
        for spacing in [CGFloat(-1), CGFloat.nan, CGFloat.infinity] {
            #expect(ReaderFittedLayout(sessionID: id, revision: 0, viewportSize: CGSize(width: 200, height: 200),
                displayMode: .fitWidth, pageSpacing: spacing, metadata: []) == nil)
        }
        for height in [CGFloat(0), CGFloat(-1), CGFloat.nan, CGFloat.infinity] {
            #expect(ReaderFittedLayout(sessionID: id, revision: 0, viewportSize: CGSize(width: 200, height: 200),
                displayMode: .fitWidth, pageSpacing: 0, metadata: [nil], placeholderHeight: height) == nil)
        }
    }

    @Test func invalidKnownDimensionsAndDerivedOverflowAreRejected() {
        for metadata in [ReaderPageMetadata(pixelWidth: 0, pixelHeight: 100),
                         ReaderPageMetadata(pixelWidth: 100, pixelHeight: -1),
                         ReaderPageMetadata(pixelWidth: Double.nan, pixelHeight: 100),
                         ReaderPageMetadata(pixelWidth: 100, pixelHeight: Double.infinity),
                         ReaderPageMetadata(pixelWidth: 1, pixelHeight: Double.greatestFiniteMagnitude),
                         ReaderPageMetadata(pixelWidth: Double.greatestFiniteMagnitude,
                                            pixelHeight: Double.leastNonzeroMagnitude)] {
            #expect(ReaderFittedLayout(sessionID: UUID(), revision: 0,
                viewportSize: CGSize(width: 200, height: 200), displayMode: .fitWidth,
                pageSpacing: 0, metadata: [metadata]) == nil)
        }
        #expect(ReaderFittedLayout(sessionID: UUID(), revision: 0,
            viewportSize: CGSize(width: 200, height: 200), displayMode: .fitWidth,
            pageSpacing: CGFloat.greatestFiniteMagnitude / 2, metadata: [nil]) == nil)
    }

    @Test func actualViewportControlsFitForNarrowAndTabletSizedInputs() throws {
        for size in [CGSize(width: 320, height: 800), CGSize(width: 1024, height: 768)] {
            let layout = try #require(ReaderFittedLayout(sessionID: UUID(), revision: 0,
                viewportSize: size, displayMode: .fitWidth, pageSpacing: 0,
                metadata: [ReaderPageMetadata(pixelWidth: 200, pixelHeight: 600)]))
            #expect(layout.geometry.pageFrames[0].width == size.width)
            #expect(layout.geometry.pageFrames[0].height == size.width * 3)
        }
    }
}
