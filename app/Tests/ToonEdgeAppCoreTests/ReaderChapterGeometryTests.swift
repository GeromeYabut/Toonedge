import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore

struct ReaderChapterGeometryTests {
    @Test func normalizedAnchorProjectsIntoChangedDimensions() throws {
        let id = UUID()
        let original = try #require(ReaderChapterGeometry(
            sessionID: id, revision: 1,
            pageFrames: [CGRect(x: 0, y: 0, width: 200, height: 200),
                         CGRect(x: 0, y: 200, width: 200, height: 200)]
        ))
        let anchor = try #require(original.anchor(at: CGPoint(x: 100, y: 300)))
        #expect(anchor.sessionID == id)
        #expect(anchor.pageIndex == 1)
        #expect(anchor.unitPoint == CGPoint(x: 0.5, y: 0.5))
        let changed = try #require(ReaderChapterGeometry(
            sessionID: id, revision: 2,
            pageFrames: [CGRect(x: 0, y: 0, width: 400, height: 400),
                         CGRect(x: 0, y: 400, width: 400, height: 400)]
        ))
        #expect(changed.point(for: anchor) == CGPoint(x: 200, y: 600))
        #expect(original.point(for: anchor) == CGPoint(x: 100, y: 300))
    }

    @Test func sharedBorderCaptureChoosesLowerIndex() throws {
        let geometry = try #require(ReaderChapterGeometry(
            sessionID: UUID(), revision: 0,
            pageFrames: [CGRect(x: 0, y: 0, width: 100, height: 100),
                         CGRect(x: 0, y: 100, width: 100, height: 100)]
        ))
        let anchor = try #require(geometry.anchor(at: CGPoint(x: 100, y: 100)))
        #expect(anchor.pageIndex == 0)
        #expect(anchor.unitPoint == CGPoint(x: 1, y: 1))
    }

    @Test func captureRejectsGapsOutsideAndInvalidPoints() throws {
        let geometry = try #require(ReaderChapterGeometry(
            sessionID: UUID(), revision: 0,
            pageFrames: [CGRect(x: 0, y: 0, width: 100, height: 100),
                         CGRect(x: 0, y: 200, width: 100, height: 100)]
        ))
        for point in [CGPoint(x: 50, y: 150), CGPoint(x: -1, y: 50),
                      CGPoint(x: 50, y: 301), CGPoint(x: CGFloat.nan, y: 50),
                      CGPoint(x: 50, y: CGFloat.infinity)] {
            #expect(geometry.anchor(at: point) == nil)
        }
    }

    @Test func projectionRejectsForeignSessionIndexAndUnitPoint() throws {
        let id = UUID()
        let geometry = try #require(ReaderChapterGeometry(
            sessionID: id, revision: 4,
            pageFrames: [CGRect(x: 20, y: 10, width: 200, height: 400)]
        ))
        let anchors = [
            ReaderSemanticAnchor(sessionID: UUID(), pageIndex: 0, unitPoint: .zero),
            ReaderSemanticAnchor(sessionID: id, pageIndex: -1, unitPoint: .zero),
            ReaderSemanticAnchor(sessionID: id, pageIndex: 1, unitPoint: .zero),
            ReaderSemanticAnchor(sessionID: id, pageIndex: 0, unitPoint: CGPoint(x: -0.1, y: 0)),
            ReaderSemanticAnchor(sessionID: id, pageIndex: 0, unitPoint: CGPoint(x: 0, y: 1.1)),
            ReaderSemanticAnchor(sessionID: id, pageIndex: 0, unitPoint: CGPoint(x: CGFloat.nan, y: 0))
        ]
        for anchor in anchors { #expect(geometry.point(for: anchor) == nil) }
        let valid = ReaderSemanticAnchor(sessionID: id, pageIndex: 0,
                                         unitPoint: CGPoint(x: 0.25, y: 0.75))
        #expect(geometry.point(for: valid) == CGPoint(x: 70, y: 310))
    }

    @Test func invalidRectanglesAndOrderingAreRejected() {
        let id = UUID()
        for invalid in [CGRect.zero, CGRect.null, CGRect.infinite,
                        CGRect(x: 0, y: 0, width: -1, height: 100),
                        CGRect(x: 0, y: 0, width: 100, height: -1),
                        CGRect(x: CGFloat.greatestFiniteMagnitude / 2, y: 0, width: 1, height: 100),
                        CGRect(x: 0, y: CGFloat.nan, width: 100, height: 100),
                        CGRect(x: 0, y: 0, width: 100, height: CGFloat.infinity)] {
            #expect(ReaderChapterGeometry(sessionID: id, revision: 0,
                                         pageFrames: [invalid]) == nil)
        }
        let first = CGRect(x: 0, y: 0, width: 100, height: 100)
        let overlap = CGRect(x: 0, y: 50, width: 100, height: 100)
        #expect(ReaderChapterGeometry(sessionID: id, revision: 0,
                                     pageFrames: [first, overlap]) == nil)
        #expect(ReaderChapterGeometry(sessionID: id, revision: 0,
                                     pageFrames: [overlap, first]) == nil)
    }

    @Test func emptyChapterIsValidButCannotCaptureAnAnchor() throws {
        let geometry = try #require(ReaderChapterGeometry(sessionID: UUID(),
                                                         revision: 7, pageFrames: []))
        #expect(geometry.revision == 7)
        #expect(geometry.pageFrames.isEmpty)
        #expect(geometry.anchor(at: .zero) == nil)
    }
}
