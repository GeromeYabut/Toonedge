import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore

struct ReaderPageMaterializationPolicyTests {
    struct Trace: Sendable {
        let viewport: CGRect
        let expected: [Int]
    }

    @Test(arguments: [
        Trace(viewport: CGRect(x: 0, y: 125, width: 100, height: 50), expected: [0, 1, 2]),
        Trace(viewport: CGRect(x: 0, y: 50, width: 100, height: 200), expected: [0, 1, 2, 3]),
        Trace(viewport: CGRect(x: 0, y: 100, width: 100, height: 100), expected: [0, 1, 2]),
        Trace(viewport: CGRect(x: 0, y: 0, width: 100, height: 50), expected: [0, 1]),
        Trace(viewport: CGRect(x: 0, y: 350, width: 100, height: 50), expected: [2, 3]),
        Trace(viewport: CGRect(x: 0, y: 500, width: 100, height: 10), expected: [2, 3]),
        Trace(viewport: CGRect(x: 0, y: -100, width: 100, height: 10), expected: [0, 1]),
        Trace(viewport: CGRect(x: 200, y: 125, width: 100, height: 50), expected: [1, 2]),
        Trace(viewport: CGRect(x: 200, y: 125, width: 100, height: 10), expected: [0, 1])
    ])
    func windowMatchesDeclaredIndexes(trace: Trace) throws {
        let geometry = try #require(ReaderChapterGeometry(
            sessionID: UUID(), revision: 0,
            pageFrames: (0..<4).map { CGRect(x: 0, y: CGFloat($0 * 100), width: 100, height: 100) }
        ))
        #expect(ReaderPageMaterializationPolicy.indexes(in: geometry,
                                                     viewport: trace.viewport) == trace.expected)
    }

    @Test func gapDistanceTieChoosesLowerPageThenOneNeighbor() throws {
        let geometry = try #require(ReaderChapterGeometry(
            sessionID: UUID(), revision: 0,
            pageFrames: [CGRect(x: 0, y: 0, width: 100, height: 100),
                         CGRect(x: 0, y: 200, width: 100, height: 100),
                         CGRect(x: 0, y: 400, width: 100, height: 100)]
        ))
        #expect(ReaderPageMaterializationPolicy.indexes(in: geometry,
            viewport: CGRect(x: 0, y: 145, width: 100, height: 10)) == [0, 1])
    }

    @Test func horizontalVisibilityGapDoesNotFillUnusedSlots() throws {
        let geometry = try #require(ReaderChapterGeometry(
            sessionID: UUID(), revision: 0,
            pageFrames: [CGRect(x: 0, y: 0, width: 100, height: 100),
                         CGRect(x: 0, y: 100, width: 50, height: 100),
                         CGRect(x: 0, y: 200, width: 100, height: 100)]
        ))
        #expect(ReaderPageMaterializationPolicy.indexes(in: geometry,
            viewport: CGRect(x: 75, y: 0, width: 25, height: 300)) == [0, 2])
    }

    @Test func unequalShortPagesMaterializeAllVisiblePlusTwo() throws {
        let geometry = try #require(ReaderChapterGeometry(
            sessionID: UUID(), revision: 0,
            pageFrames: [CGRect(x: 0, y: 0, width: 100, height: 10),
                         CGRect(x: 0, y: 10, width: 100, height: 20),
                         CGRect(x: 0, y: 30, width: 100, height: 10),
                         CGRect(x: 0, y: 40, width: 100, height: 20),
                         CGRect(x: 0, y: 60, width: 100, height: 10),
                         CGRect(x: 0, y: 70, width: 100, height: 20),
                         CGRect(x: 0, y: 90, width: 100, height: 10)]
        ))
        // Five visible pages (1...5), plus one neighbor at each end.
        #expect(ReaderPageMaterializationPolicy.indexes(in: geometry,
            viewport: CGRect(x: 0, y: 15, width: 100, height: 60)) == [0, 1, 2, 3, 4, 5, 6])
    }

    @Test func emptyAndSinglePageChaptersStayWithinTheirBounds() throws {
        let viewport = CGRect(x: 0, y: 500, width: 100, height: 50)
        let empty = try #require(ReaderChapterGeometry(sessionID: UUID(), revision: 0,
                                                      pageFrames: []))
        #expect(ReaderPageMaterializationPolicy.indexes(in: empty, viewport: viewport) == [])
        let single = try #require(ReaderChapterGeometry(sessionID: UUID(), revision: 0,
            pageFrames: [CGRect(x: 0, y: 0, width: 100, height: 100)]))
        #expect(ReaderPageMaterializationPolicy.indexes(in: single, viewport: viewport) == [0])
    }

    @Test func invalidViewportAndOverflowingDistanceAreUnavailable() throws {
        let geometry = try #require(ReaderChapterGeometry(sessionID: UUID(), revision: 0,
            pageFrames: [CGRect(x: 0, y: 0, width: 100, height: 100)]))
        for invalid in [CGRect.zero, CGRect.null, CGRect.infinite,
                        CGRect(x: 0, y: 0, width: -100, height: 100),
                        CGRect(x: 0, y: 0, width: 100, height: -100),
                        CGRect(x: CGFloat.nan, y: 0, width: 100, height: 100)] {
            #expect(ReaderPageMaterializationPolicy.indexes(in: geometry, viewport: invalid) == nil)
        }
        let magnitude = CGFloat.greatestFiniteMagnitude
        let extreme = try #require(ReaderChapterGeometry(sessionID: UUID(), revision: 0,
            pageFrames: [CGRect(x: 0, y: -0.9 * magnitude, width: 100, height: 0.1 * magnitude)]))
        #expect(ReaderPageMaterializationPolicy.indexes(in: extreme,
            viewport: CGRect(x: 0, y: 0.8 * magnitude, width: 100, height: 0.1 * magnitude)) == nil)
    }
}
