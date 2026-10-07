import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore

struct ReaderPresentationTransformTests {
    private func makeLayout(sessionID: UUID = UUID(), revision: UInt64 = 0,
                            viewport: CGSize = CGSize(width: 200, height: 100),
                            height: Double = 600) -> ReaderFittedLayout? {
        ReaderFittedLayout(sessionID: sessionID, revision: revision, viewportSize: viewport,
            displayMode: .fitWidth, pageSpacing: 0,
            metadata: [ReaderPageMetadata(pixelWidth: 200, pixelHeight: height)])
    }

    @Test func reachableFocalPointAndInverseViewportArePreserved() throws {
        let layout = try #require(makeLayout())
        let anchor = try #require(layout.geometry.anchor(at: CGPoint(x: 100, y: 300)))
        let transform = try #require(ReaderPresentationTransform(layout: layout, scale: 2,
            anchor: anchor, viewportPoint: CGPoint(x: 80, y: 60)))
        #expect(transform.translation == CGPoint(x: -120, y: -540))
        #expect(transform.viewportPoint(for: anchor) == CGPoint(x: 80, y: 60))
        #expect(transform.logicalViewport == CGRect(x: 60, y: 270, width: 100, height: 50))
        let maximum = try #require(ReaderPresentationTransform(layout: layout, scale: 3,
            anchor: anchor, viewportPoint: CGPoint(x: 80, y: 60)))
        #expect(maximum.translation == CGPoint(x: -220, y: -840))
        #expect(maximum.viewportPoint(for: anchor) == CGPoint(x: 80, y: 60))
    }

    @Test func panClampsBothOverflowingAxesAndReversesWithoutOvershoot() throws {
        let layout = try #require(makeLayout())
        let anchor = ReaderSemanticAnchor(sessionID: layout.geometry.sessionID, pageIndex: 0,
                                          unitPoint: CGPoint(x: 0.5, y: 0.5))
        let original = try #require(ReaderPresentationTransform(layout: layout, scale: 2,
            anchor: anchor, viewportPoint: CGPoint(x: 80, y: 60)))
        let upper = try #require(original.panned(by: CGPoint(x: 1000, y: 1000)))
        #expect(upper.translation == .zero)
        let reversed = try #require(upper.panned(by: CGPoint(x: -1, y: -1)))
        #expect(reversed.translation == CGPoint(x: -1, y: -1))
        let lower = try #require(original.panned(by: CGPoint(x: -1000, y: -10000)))
        #expect(lower.translation == CGPoint(x: -200, y: -1100))
        #expect(original.translation == CGPoint(x: -120, y: -540))
    }

    @Test func belowBaselineShortChapterKeepsVerticalAnchorWithoutPanRange() throws {
        let layout = try #require(makeLayout(viewport: CGSize(width: 200, height: 200), height: 100))
        let anchor = try #require(layout.geometry.anchor(at: CGPoint(x: 100, y: 80)))
        let transform = try #require(ReaderPresentationTransform(layout: layout, scale: 0.75,
            anchor: anchor, viewportPoint: CGPoint(x: 100, y: 80)))
        #expect(transform.translation == CGPoint(x: 25, y: 20))
        #expect(transform.viewportPoint(for: anchor) == CGPoint(x: 100, y: 80))
        let panned = try #require(transform.panned(by: CGPoint(x: 30, y: 30)))
        #expect(panned.translation == transform.translation)
        let baseline = try #require(ReaderPresentationTransform(layout: layout, scale: 1,
            anchor: anchor, viewportPoint: CGPoint(x: 100, y: 80)))
        #expect(baseline.translation == .zero)
        #expect(baseline.viewportPoint(for: anchor) == CGPoint(x: 100, y: 80))
    }

    @Test func baselineOffsetUsesNormalAlignmentButDoesNotGrantPermission() throws {
        let layout = try #require(makeLayout())
        let anchor = try #require(layout.geometry.anchor(at: CGPoint(x: 100, y: 300)))
        let baseline = try #require(ReaderPresentationTransform(layout: layout, scale: 1,
            anchor: anchor, viewportPoint: CGPoint(x: 100, y: 60)))
        #expect(baseline.translation == CGPoint(x: 0, y: -240))
        let moved = try #require(baseline.panned(by: CGPoint(x: 100, y: 10)))
        #expect(moved.translation == CGPoint(x: 0, y: -230))
        #expect(moved.viewportPoint(for: anchor) == CGPoint(x: 100, y: 70))
    }

    @Test func unreachableEdgeAndMandatoryCenteringReturnActualPoint() throws {
        let layout = try #require(makeLayout())
        let anchor = try #require(layout.geometry.anchor(at: .zero))
        let clamped = try #require(ReaderPresentationTransform(layout: layout, scale: 2,
            anchor: anchor, viewportPoint: CGPoint(x: 100, y: 50)))
        #expect(clamped.translation == .zero)
        #expect(clamped.viewportPoint(for: anchor) == .zero)
        let short = try #require(makeLayout(viewport: CGSize(width: 200, height: 200), height: 100))
        let shortAnchor = try #require(short.geometry.anchor(at: .zero))
        let centered = try #require(ReaderPresentationTransform(layout: short, scale: 0.75,
            anchor: shortAnchor, viewportPoint: .zero))
        #expect(centered.viewportPoint(for: shortAnchor) == CGPoint(x: 25, y: 0))
    }

    @Test func normalizedAnchorReprojectsAfterDecodedDimensionsChange() throws {
        let id = UUID()
        let old = try #require(makeLayout(sessionID: id, revision: 1))
        let anchor = try #require(old.geometry.anchor(at: CGPoint(x: 100, y: 300)))
        let changed = try #require(makeLayout(sessionID: id, revision: 2, height: 1000))
        let transform = try #require(ReaderPresentationTransform(layout: changed, scale: 2,
            anchor: anchor, viewportPoint: CGPoint(x: 80, y: 60)))
        #expect(transform.translation == CGPoint(x: -120, y: -940))
        #expect(transform.viewportPoint(for: anchor) == CGPoint(x: 80, y: 60))
        #expect(old.geometry.point(for: anchor) == CGPoint(x: 100, y: 300))
        #expect(changed.geometry.point(for: anchor) == CGPoint(x: 100, y: 500))
    }

    @Test func invalidScalesTargetsForeignAnchorsAndPanAreRejected() throws {

        let layout = try #require(makeLayout())
        let anchor = try #require(layout.geometry.anchor(at: CGPoint(x: 100, y: 300)))
        for scale in [CGFloat(0), CGFloat(-1), CGFloat.nan, CGFloat.infinity, CGFloat.greatestFiniteMagnitude] {
            #expect(ReaderPresentationTransform(layout: layout, scale: scale,
                anchor: anchor, viewportPoint: CGPoint(x: 100, y: 50)) == nil)
        }
        for point in [CGPoint(x: -1, y: 0), CGPoint(x: 201, y: 0), CGPoint(x: 0, y: 101),
                      CGPoint(x: CGFloat.nan, y: 0), CGPoint(x: 0, y: CGFloat.infinity)] {
            #expect(ReaderPresentationTransform(layout: layout, scale: 2,
                anchor: anchor, viewportPoint: point) == nil)
        }
        let foreign = ReaderSemanticAnchor(sessionID: UUID(), pageIndex: 0, unitPoint: .zero)
        #expect(ReaderPresentationTransform(layout: layout, scale: 2,
            anchor: foreign, viewportPoint: .zero) == nil)
        let valid = try #require(ReaderPresentationTransform(layout: layout, scale: 2,
            anchor: anchor, viewportPoint: CGPoint(x: 100, y: 50)))
        #expect(valid.panned(by: CGPoint(x: CGFloat.nan, y: 0)) == nil)
        #expect(valid.panned(by: CGPoint(x: 0, y: CGFloat.infinity)) == nil)
        #expect(valid.viewportPoint(for: foreign) == nil)
    }

    @Test func finiteScaleWithUnrepresentableInverseIsRejected() throws {
        let layout = try #require(makeLayout())
        let anchor = ReaderSemanticAnchor(sessionID: layout.geometry.sessionID,
            pageIndex: 0, unitPoint: .zero)
        #expect(ReaderPresentationTransform(layout: layout,
            scale: CGFloat.leastNormalMagnitude, anchor: anchor, viewportPoint: .zero) == nil)
    }

    @Test func emptyLayoutCannotPresentAnAbsentAnchor() throws {
        let layout = try #require(ReaderFittedLayout(sessionID: UUID(), revision: 0,
            viewportSize: CGSize(width: 200, height: 100), displayMode: .fitWidth,
            pageSpacing: 0, metadata: []))
        let absent = ReaderSemanticAnchor(sessionID: layout.geometry.sessionID,
            pageIndex: 0, unitPoint: .zero)
        #expect(ReaderPresentationTransform(layout: layout, scale: 1,
            anchor: absent, viewportPoint: .zero) == nil)
        #expect(ReaderPageMaterializationPolicy.indexes(in: layout.geometry,
            viewport: CGRect(origin: .zero, size: layout.viewportSize)) == [])
    }

    @Test func repeatedFinitePanRejectsUnrepresentableAddition() throws {
        let layout = try #require(makeLayout(
            viewport: CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude / 8),
            height: Double.greatestFiniteMagnitude / 4))
        let anchor = ReaderSemanticAnchor(sessionID: layout.geometry.sessionID,
            pageIndex: 0, unitPoint: CGPoint(x: 0.5, y: 0.5))
        let original = try #require(ReaderPresentationTransform(layout: layout, scale: 2,
            anchor: anchor, viewportPoint: CGPoint(x: 100, y: 50)))
        let moved = try #require(original.panned(by:
            CGPoint(x: 0, y: -CGFloat.greatestFiniteMagnitude / 2)))
        #expect(moved.panned(by: CGPoint(x: 0, y: -CGFloat.greatestFiniteMagnitude)) == nil)
    }

    @Test func inverseViewportFeedsExistingMaterializationPolicy() throws {
        let layout = try #require(ReaderFittedLayout(sessionID: UUID(), revision: 4,
            viewportSize: CGSize(width: 200, height: 100), displayMode: .fitWidth, pageSpacing: 0,
            metadata: [ReaderPageMetadata(pixelWidth: 200, pixelHeight: 200),
                       ReaderPageMetadata(pixelWidth: 200, pixelHeight: 200)]))
        let anchor = try #require(layout.geometry.anchor(at: CGPoint(x: 100, y: 300)))
        let transform = try #require(ReaderPresentationTransform(layout: layout, scale: 2,
            anchor: anchor, viewportPoint: CGPoint(x: 100, y: 50)))
        #expect(transform.logicalViewport == CGRect(x: 50, y: 275, width: 100, height: 50))
        #expect(ReaderPageMaterializationPolicy.indexes(in: layout.geometry,
                                                     viewport: transform.logicalViewport) == [0, 1])
    }

    @Test func focalMathUsesActualViewportNotDeviceClass() throws {
        for size in [CGSize(width: 320, height: 800), CGSize(width: 1024, height: 768)] {
            let layout = try #require(makeLayout(viewport: size, height: 1200))
            let anchor = ReaderSemanticAnchor(sessionID: layout.geometry.sessionID, pageIndex: 0,
                                              unitPoint: CGPoint(x: 0.5, y: 0.5))
            let target = CGPoint(x: size.width / 2, y: size.height / 2)
            let transform = try #require(ReaderPresentationTransform(layout: layout, scale: 2,
                anchor: anchor, viewportPoint: target))
            let actual = try #require(transform.viewportPoint(for: anchor))
            #expect(abs(actual.x - target.x) < 1e-8)
            #expect(abs(actual.y - target.y) < 1e-8)
        }
    }

    @Test func normalizedAnchorSurvivesFitSpacingAndUsableViewportChanges() throws {
        let id = UUID()
        let old = try #require(makeLayout(sessionID: id, revision: 1))
        let anchor = try #require(old.geometry.anchor(at: CGPoint(x: 100, y: 300)))
        // New usable viewport after inset/size changes; not a native inset measurement.
        let changed = try #require(ReaderFittedLayout(sessionID: id, revision: 2,
            viewportSize: CGSize(width: 300, height: 200), displayMode: .fitScreen, pageSpacing: 8,
            metadata: [ReaderPageMetadata(pixelWidth: 200, pixelHeight: 600)]))
        let transform = try #require(ReaderPresentationTransform(layout: changed, scale: 2,
            anchor: anchor, viewportPoint: CGPoint(x: 100, y: 100)))
        let actual = try #require(transform.viewportPoint(for: anchor))
        #expect(abs(actual.x - 100) < 1e-8)
        #expect(abs(actual.y - 100) < 1e-8)
        #expect(transform.layout.geometry.revision == 2)
        #expect(transform.layout.viewportSize == CGSize(width: 300, height: 200))
    }
}
