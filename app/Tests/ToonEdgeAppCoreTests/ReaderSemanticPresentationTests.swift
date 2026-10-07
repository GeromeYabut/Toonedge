import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore

func coordinatorLayout(sessionID: UUID, revision: UInt64 = 0,
                       heights: [Double?] = [600],
                       viewport: CGSize = CGSize(width: 200, height: 100),
                       spacing: CGFloat = 0,
                       mode: ReaderDisplayMode = .fitWidth) throws -> ReaderFittedLayout {
    try #require(ReaderFittedLayout(sessionID: sessionID, revision: revision,
        viewportSize: viewport, displayMode: mode, pageSpacing: spacing,
        metadata: heights.map { value in
            value.map { ReaderPageMetadata(pixelWidth: 200, pixelHeight: $0) }
        }))
}

func coordinatorMeasurement(_ request: ReaderPresentationRequest,
                            scale: CGFloat? = nil, point: CGPoint? = nil,
                            layoutCurrent: Bool = true,
                            decodedCurrent: Bool = true) -> ReaderPresentationMeasurement {
    ReaderPresentationMeasurement(token: request.token, anchor: request.target.anchor,
        actualScale: scale ?? request.target.scale,
        actualPoint: point ?? request.target.viewportPoint,
        layoutCurrent: layoutCurrent, decodedCurrent: decodedCurrent)
}

struct ReaderSemanticPresentationTests {
    @Test func bootstrapUsesBoundedActualPlacement() throws {
        let layout = try coordinatorLayout(sessionID: UUID(), heights: [40, 40])
        let target = try #require(ReaderSemanticPresentation.bootstrap(index: 1, in: layout))
        #expect(target.scale == 1)
        #expect(target.anchor.pageIndex == 1)
        #expect(target.viewportPoint == CGPoint(x: 100, y: 40))
        #expect(target.reproject(in: layout) != nil)
    }

    @Test func boundedPanRebasesOffscreenFocalPoint() throws {
        let layout = try coordinatorLayout(sessionID: UUID())
        let old = ReaderSemanticAnchor(sessionID: layout.geometry.sessionID,
            pageIndex: 0, unitPoint: CGPoint(x: 0.5, y: 0.5))
        let transform = try #require(ReaderPresentationTransform(layout: layout,
            scale: 2, anchor: old, viewportPoint: CGPoint(x: 80, y: 60)))
        let panned = try #require(transform.panned(by: CGPoint(x: 1000, y: 1000)))
        let target = try #require(ReaderSemanticPresentation.capture(panned, preferredAnchor: old))
        #expect(target.anchor != old)
        #expect(target.viewportPoint == CGPoint(x: 100, y: 50))
        #expect(target.reproject(in: layout)?.translation == panned.translation)
    }

    @Test func belowBaselineCenteringIsAcceptedButLaterReprojectionIsStrict() throws {
        let id = UUID()
        let layout = try coordinatorLayout(sessionID: id)
        let anchor = ReaderSemanticAnchor(sessionID: id, pageIndex: 0, unitPoint: .zero)
        let transform = try #require(ReaderPresentationTransform(layout: layout,
            scale: 0.75, anchor: anchor, viewportPoint: .zero))
        let target = try #require(ReaderSemanticPresentation.capture(transform, preferredAnchor: anchor))
        #expect(target.viewportPoint.x == 25)
        let changed = try coordinatorLayout(sessionID: id, revision: 1,
            viewport: CGSize(width: 400, height: 100))
        #expect(target.reproject(in: changed) == nil)
    }

    @Test func gapAndInvalidTargetsAreRejected() throws {
        let layout = try coordinatorLayout(sessionID: UUID(), heights: [10, 10], spacing: 300)
        let anchor = ReaderSemanticAnchor(sessionID: layout.geometry.sessionID,
            pageIndex: 0, unitPoint: CGPoint(x: 0.5, y: 0))
        let initial = try #require(ReaderPresentationTransform(layout: layout,
            scale: 1, anchor: anchor, viewportPoint: .zero))
        let gap = try #require(initial.panned(by: CGPoint(x: 0, y: -150)))
        #expect(ReaderSemanticPresentation.capture(gap, preferredAnchor: anchor) == nil)
        let edgeAnchor = ReaderSemanticAnchor(sessionID: layout.geometry.sessionID,
            pageIndex: 0, unitPoint: CGPoint(x: 0.5, y: 1))
        let edgeOnly = try #require(ReaderPresentationTransform(layout: layout,
            scale: 0.75, anchor: edgeAnchor, viewportPoint: CGPoint(x: 100, y: 0)))
        #expect(ReaderSemanticPresentation.capture(edgeOnly, preferredAnchor: edgeAnchor) == nil)
        #expect(ReaderSemanticPresentation(scale: .nan, anchor: anchor, viewportPoint: .zero) == nil)
        #expect(ReaderSemanticPresentation(scale: 3.1, anchor: anchor, viewportPoint: .zero) == nil)
        #expect(ReaderSemanticPresentation(scale: 1, anchor: anchor,
            viewportPoint: CGPoint(x: CGFloat.infinity, y: 0)) == nil)
        #expect(ReaderSemanticPresentation.bootstrap(index: -1, in: layout) == nil)
        let empty = try coordinatorLayout(sessionID: UUID(), heights: [])
        #expect(ReaderSemanticPresentation.bootstrap(index: 0, in: empty) == nil)
    }

    @Test func normalizedTargetSurvivesDecodedDimensionsAndFitChanges() throws {
        let id = UUID()
        let old = try coordinatorLayout(sessionID: id)
        let anchor = ReaderSemanticAnchor(sessionID: id, pageIndex: 0,
            unitPoint: CGPoint(x: 0.5, y: 0.5))
        let target = try #require(ReaderSemanticPresentation(scale: 2, anchor: anchor,
            viewportPoint: CGPoint(x: 100, y: 50)))
        #expect(target.reproject(in: old) != nil)
        let changed = try coordinatorLayout(sessionID: id, revision: 1, heights: [1000],
            viewport: CGSize(width: 300, height: 200), spacing: 8, mode: .fitScreen)
        #expect(target.reproject(in: changed)?.viewportPoint(for: anchor) == target.viewportPoint)
        let narrow = try coordinatorLayout(sessionID: id, revision: 2,
            viewport: CGSize(width: 80, height: 40))
        #expect(target.reproject(in: narrow) == nil)
    }
}
