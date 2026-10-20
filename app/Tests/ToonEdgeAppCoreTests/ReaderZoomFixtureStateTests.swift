import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore

struct ReaderZoomFixtureStateTests {
    private let viewport = CGSize(width: 300, height: 500)
    private let center = CGPoint(x: 150, y: 250)

    private func makeState() throws -> ReaderZoomFixtureState {
        var state = try #require(ReaderZoomFixtureState(
            sessionID: UUID(), viewportSize: viewport, pageCount: 80))
        state.beginPan()
        state.pan(by: CGPoint(x: 0, y: -1000))
        state.endPan(cancelled: false)
        return state
    }

    @Test func boundsAndStickyBreakthroughRetainCommittedScale() throws {
        var state = try makeState()
        state.inspect(scale: 2, at: center)
        state.beginPinch(at: center)
        state.updatePinch(magnification: 0.5, at: center)
        #expect(abs(state.presentation.scale - 1) < 1e-9)
        state.updatePinch(magnification: 0.44, at: center)
        #expect(abs(state.presentation.scale - 1) < 1e-9)
        state.updatePinch(magnification: 0.43, at: center)
        #expect(state.presentation.scale < 1)
        let retained = state.presentation
        state.endPinch()
        #expect(state.presentation == retained)
        state.beginPinch(at: center)
        state.updatePinch(magnification: 1000, at: center)
        #expect(state.presentation.scale == 3)
        state.updatePinch(magnification: 0.001, at: center)
        state.updatePinch(magnification: 0.0001, at: center)
        #expect(state.presentation.scale == 0.75)
    }

    @Test func frozenReadingAnchorSurvivesInspectionPanAndReset() throws {
        var state = try makeState()
        let baseline = state.presentation
        state.inspect(scale: 2, at: center)
        let frozen = try #require(state.frozenReading)
        state.beginPan()
        state.pan(by: CGPoint(x: -80, y: -600))
        state.endPan(cancelled: false)
        #expect(state.frozenReading == frozen)
        state.reset()
        #expect(state.presentation.scale == 1)
        #expect(abs(state.presentation.translation.x - baseline.translation.x) < 1e-7)
        #expect(abs(state.presentation.translation.y - baseline.translation.y) < 1e-7)
        #expect(!state.resetReconciled)
        let first = try #require(state.resetRequest)
        state.reset()
        let current = try #require(state.resetRequest)
        #expect(first.id != current.id)
        let acknowledgedStale = state.acknowledgeReset(
            first, measuredPoint: first.target.viewportPoint)
        #expect(!acknowledgedStale)
        let acknowledgedOutsideTolerance = state.acknowledgeReset(current, measuredPoint:
            CGPoint(x: current.target.viewportPoint.x + 2.1,
                    y: current.target.viewportPoint.y))
        #expect(!acknowledgedOutsideTolerance)
        let acknowledgedCurrent = state.acknowledgeReset(
            current, measuredPoint: current.target.viewportPoint)
        #expect(acknowledgedCurrent)
        #expect(state.resetReconciled)
    }

    @Test func pinchKeepsReachableFocalPointUnderMovingCentroid() throws {
        var state = try makeState()
        let logical = CGPoint(x: 150, y: 1250)
        let anchor = try #require(state.layout.geometry.anchor(at: logical))
        state.beginPinch(at: center)
        let moved = CGPoint(x: 140, y: 270)
        state.updatePinch(magnification: 2, at: moved)
        let actual = try #require(state.presentation.viewportPoint(for: anchor))
        #expect(abs(actual.x - moved.x) < 1e-7)
        #expect(abs(actual.y - moved.y) < 1e-7)
        state.endPinch()
        #expect(state.presentation.scale == 2)
    }

    @Test func cancelledPinchAndPanRestoreLastCommittedPresentation() throws {
        for scale in [CGFloat(2), CGFloat(0.75)] {
            var state = try makeState()
            state.inspect(scale: scale, at: center)
            let committed = state.presentation
            state.beginPinch(at: center)
            state.updatePinch(magnification: 1.2, at: CGPoint(x: 160, y: 260))
            state.cancelPinch()
            #expect(state.presentation == committed)
            state.beginPan()
            state.pan(by: CGPoint(x: -10000, y: -100000))
            state.endPan(cancelled: true)
            #expect(state.presentation == committed)
        }
    }

    @Test func doubleTapAndSessionReplacementInvalidateOldReset() throws {
        var state = try makeState()
        let baseline = state.presentation
        state.doubleTap(at: center)
        #expect(state.presentation.scale == 2)
        state.doubleTap(at: center)
        #expect(state.presentation.scale == 1)
        #expect(abs(state.presentation.translation.x - baseline.translation.x) < 1e-7)
        #expect(abs(state.presentation.translation.y - baseline.translation.y) < 1e-7)
        let oldRequest = try #require(state.resetRequest)
        let nextID = UUID()
        let replacedSession = state.replaceSession(
            sessionID: nextID, viewportSize: viewport, pageCount: 3)
        #expect(replacedSession)
        #expect(state.layout.geometry.sessionID == nextID)
        #expect(state.presentation.scale == 1)
        #expect(state.frozenReading == nil)
        let acknowledgedPreviousSession = state.acknowledgeReset(
            oldRequest, measuredPoint: oldRequest.target.viewportPoint)
        #expect(!acknowledgedPreviousSession)
    }

    @Test func materializationStaysBoundedAcrossChapterPositionsAndScales() throws {
        var state = try makeState()
        for index in [0, 40, 79] {
            state.jump(to: index)
            for scale in [CGFloat(0.75), CGFloat(1), CGFloat(3)] {
                if scale == 1 { state.reset() } else { state.inspect(scale: scale, at: center) }
                #expect(state.materializedIndexes.count <=
                    (state.visibleIndexes.isEmpty ? 2 : state.visibleIndexes.count + 2))
                #expect(Set(state.visibleIndexes).isSubset(of: Set(state.materializedIndexes)))
            }
        }
        let geometry = try #require(ReaderChapterGeometry(sessionID: UUID(), revision: 0,
            pageFrames: [CGRect(x: 0, y: 0, width: 300, height: 10),
                         CGRect(x: 0, y: 100, width: 300, height: 10),
                         CGRect(x: 0, y: 200, width: 300, height: 10)]))
        let indexes = try #require(ReaderPageMaterializationPolicy.indexes(in: geometry,
            viewport: CGRect(x: 0, y: 50, width: 300, height: 1)))
        #expect(indexes.count <= 2)
    }
}
