import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore
struct ReaderZoomStateTests {
    let center = CGPoint(x: 150, y: 250)
    func layout(_ id: UUID, revision: UInt64 = 0, height: Double = 1000,
                size: CGSize = CGSize(width: 300, height: 500), spacing: CGFloat = 0) throws -> ReaderFittedLayout {
        try #require(ReaderFittedLayout(sessionID: id, revision: revision, viewportSize: size,
            displayMode: .fitWidth, pageSpacing: spacing,
            metadata: (0..<12).map { _ in ReaderPageMetadata(pixelWidth: 300, pixelHeight: height) }))
    }
    @Test func realMetadataAndEmptyChapters() throws {
        let id = UUID()
        let fitted = try #require(ReaderFittedLayout(sessionID: id, revision: 0,
            viewportSize: CGSize(width: 300, height: 500), displayMode: .fitWidth,
            pageSpacing: 0, metadata: [ReaderPageMetadata(pixelWidth: 300, pixelHeight: 900), nil,
                ReaderPageMetadata(pixelWidth: 600, pixelHeight: 600)]))
        let state = ReaderZoomState(layout: fitted)
        #expect(state.layout.geometry.pageFrames.map(\.height) == [900, 430, 300])
        #expect(state.layout.unresolvedPageIndexes == [1])
        let emptyLayout = try #require(ReaderFittedLayout(sessionID: id, revision: 0,
            viewportSize: fitted.viewportSize, displayMode: .fitWidth, pageSpacing: 0, metadata: []))
        var empty = ReaderZoomState(layout: emptyLayout)
        empty.reset(); empty.doubleTap(at: center)
        #expect(empty.presentation == nil)
        #expect(empty.materializedIndexes.isEmpty)
        #expect(empty.resetRequest == nil)
    }
    @Test func stickyCancellationAndCurrentMeasuredReset() throws {
        var state = ReaderZoomState(layout: try layout(UUID()))
        state.jump(to: 2); state.inspect(scale: 2, at: center)
        let committed = try #require(state.presentation)
        state.beginPinch(at: center); state.updatePinch(magnification: 0.5, at: center)
        #expect(state.presentation?.scale == 1)
        state.updatePinch(magnification: 0.43, at: center)
        #expect((state.presentation?.scale ?? 1) < 1)
        state.cancelPinch(); #expect(state.presentation == committed)
        state.reset(); let old = try #require(state.resetRequest)
        state.reset(); let current = try #require(state.resetRequest)
        let staleAccepted = state.acknowledgeReset(old, measuredPoint: old.target.viewportPoint)
        #expect(!staleAccepted)
        #expect(!state.canReportBaseline)
        let accepted = state.acknowledgeReset(current, measuredPoint: current.target.viewportPoint)
        #expect(accepted)
        #expect(state.canReportBaseline)
    }
    @Test func decodedRelayoutPreservesActiveFocalAndSeparateFrozenReading() throws {
        let id = UUID(); var state = ReaderZoomState(layout: try layout(id))
        state.jump(to: 3); state.inspect(scale: 2, at: center)
        let frozen = try #require(state.frozenReading)
        state.beginPan(); state.pan(by: CGPoint(x: -30, y: -120)); state.endPan(cancelled: false)
        state.beginPinch(at: center); state.updatePinch(magnification: 1.1, at: center)
        let focal = try #require(state.focalAnchor)
        let revised = try layout(id, revision: 1, height: 1200)
        let applied = state.relayout(revised)
        #expect(applied)
        let measured = try #require(state.presentation?.viewportPoint(for: focal))
        #expect(abs(measured.x - center.x) < 0.001); #expect(abs(measured.y - center.y) < 0.001)
        #expect(state.frozenReading?.anchor == frozen.anchor)
        state.cancelPinch(); #expect(state.presentation?.layout == revised)
        let staleLayout = try layout(id)
        let foreignLayout = try layout(UUID(), revision: 2)
        let staleApplied = state.relayout(staleLayout)
        let foreignApplied = state.relayout(foreignLayout)
        #expect(!staleApplied); #expect(!foreignApplied)
    }
    @Test func viewportRelayoutInvalidatesResetAcknowledgement() throws {
        let id = UUID(); var state = ReaderZoomState(layout: try layout(id))
        state.jump(to: 5); state.inspect(scale: 0.75, at: center)
        let frozen = try #require(state.frozenReading)
        state.reset(); let old = try #require(state.resetRequest)
        let revised = try layout(id, revision: 1, size: CGSize(width: 400, height: 600), spacing: 8)
        let applied = state.relayout(revised)
        #expect(applied)
        let staleAccepted = state.acknowledgeReset(old, measuredPoint: old.target.viewportPoint)
        #expect(!staleAccepted)
        #expect(state.resetRequest?.target.anchor == frozen.anchor)
        #expect(state.materializedIndexes.count <= state.visibleIndexes.count + 2)
    }
    @Test func cancellingPinchCannotBypassPendingNativeResetAcknowledgement() throws {
        var state = ReaderZoomState(layout: try layout(UUID()))
        state.jump(to: 2); state.inspect(scale: 2, at: center); state.reset()
        let old = try #require(state.resetRequest)
        state.beginPinch(at: center); state.updatePinch(magnification: 1.2, at: center)
        state.cancelPinch()
        #expect(!state.canReportBaseline)
        let current = try #require(state.resetRequest)
        #expect(current.id != old.id)
        let accepted = state.acknowledgeReset(current, measuredPoint: current.target.viewportPoint)
        #expect(accepted); #expect(state.canReportBaseline)
    }
    @Test func cancellingPanCannotBypassPendingNativeResetAcknowledgement() throws {
        let id = UUID(); var state = ReaderZoomState(layout: try layout(id))
        state.jump(to: 2); state.inspect(scale: 2, at: center); state.reset()
        let old = try #require(state.resetRequest)
        state.beginPan(); state.pan(by: CGPoint(x: 0, y: -80))
        let revised = try layout(id, revision: 1, height: 1200)
        let applied = state.relayout(revised)
        #expect(applied)
        state.endPan(cancelled: true)
        #expect(!state.canReportBaseline)
        let current = try #require(state.resetRequest)
        #expect(current.id != old.id); #expect(current.geometryRevision == 1)
        let accepted = state.acknowledgeReset(current, measuredPoint: current.target.viewportPoint)
        #expect(accepted); #expect(state.canReportBaseline)
    }
    @Test func metadataRelayoutKeepsGapCenteredPinchResponsive() throws {
        let id = UUID()
        let initial = try #require(ReaderFittedLayout(sessionID: id, revision: 0,
            viewportSize: CGSize(width: 300, height: 500), displayMode: .fitWidth,
            pageSpacing: 8, metadata: [nil, nil]))
        var state = ReaderZoomState(layout: initial)
        let midpoint = CGPoint(x: 150, y: 434)
        state.beginPinch(at: midpoint)
        state.updatePinch(magnification: 1.2, at: midpoint)
        let focal = try #require(state.focalPoint)
        #expect(abs(focal.y - 442) < 1e-8)
        #expect(focal.y > initial.geometry.pageFrames[0].maxY)
        #expect(focal.y < initial.geometry.pageFrames[1].minY)
        #expect(state.focalAnchor == nil)
        let revised = try #require(ReaderFittedLayout(sessionID: id, revision: 1,
            viewportSize: initial.viewportSize, displayMode: .fitWidth, pageSpacing: 8,
            metadata: [ReaderPageMetadata(pixelWidth: 300, pixelHeight: 600), nil]))
        try expectAnchorlessPinchContinues(&state, after: revised, at: midpoint)
    }
    @Test func metadataRelayoutKeepsClampedFitScreenGutterPinchResponsive() throws {
        let id = UUID()
        let initial = try #require(ReaderFittedLayout(sessionID: id, revision: 0,
            viewportSize: CGSize(width: 300, height: 500), displayMode: .fitScreen,
            pageSpacing: 8, metadata: [nil, nil]))
        var state = ReaderZoomState(layout: initial)
        state.beginPinch(at: CGPoint(x: 6, y: 250))
        // Moving the midpoint right clamps the presentation while its logical focal
        // remains in the gutter. Reusing that stale logical point would add a dead zone.
        let midpoint = CGPoint(x: 40, y: 250)
        state.updatePinch(magnification: 1.2, at: midpoint)
        let focal = try #require(state.focalPoint)
        #expect(focal.x < initial.geometry.pageFrames[0].minX)
        #expect(state.focalAnchor == nil)
        #expect(state.presentation?.translation.x == 0)
        let revised = try #require(ReaderFittedLayout(sessionID: id, revision: 1,
            viewportSize: CGSize(width: 400, height: 600), displayMode: .fitScreen,
            pageSpacing: 8,
            metadata: [ReaderPageMetadata(pixelWidth: 300, pixelHeight: 600), nil]))
        try expectAnchorlessPinchContinues(&state, after: revised, at: midpoint)
    }
    private func expectAnchorlessPinchContinues(_ state: inout ReaderZoomState,
                                                after revised: ReaderFittedLayout,
                                                at midpoint: CGPoint) throws {
        #expect(state.isPinching)
        #expect(state.focalAnchor == nil)
        #expect(abs(try #require(state.presentation).scale - 1.2) < 1e-8)
        let frozen = try #require(state.frozenReading)
        let oldSize = state.layout.viewportSize
        let projected = CGPoint(x: midpoint.x / oldSize.width * revised.viewportSize.width,
                                y: midpoint.y / oldSize.height * revised.viewportSize.height)
        // Both cases began from the initial baseline. Independently relayout that
        // committed state to specify cancellation's expected remapped presentation.
        var rollback = ReaderZoomState(layout: state.layout)
        let rollbackApplied = rollback.relayout(revised)
        #expect(rollbackApplied)
        let applied = state.relayout(revised)
        #expect(applied)
        #expect(state.isPinching)
        #expect(state.frozenReading?.anchor == frozen.anchor)
        let remapped = try #require(state.presentation)
        #expect(remapped.layout == revised)
        let rebased = CGPoint(x: (projected.x - remapped.translation.x) / remapped.scale,
                              y: (projected.y - remapped.translation.y) / remapped.scale)
        // Relayout already chose a bounded presentation. Replaying the last sample
        // must keep it there, including when the old gutter focal was clamped.
        state.updatePinch(magnification: 1.2, at: projected)
        let repeated = try #require(state.presentation)
        #expect(abs(repeated.scale - remapped.scale) < 1e-8)
        #expect(abs(repeated.translation.x - remapped.translation.x) < 1e-8)
        #expect(abs(repeated.translation.y - remapped.translation.y) < 1e-8)
        // The next cumulative sample must use the existing magnification history
        // and scale about the point underneath the remapped midpoint.
        let expected = CGPoint(x: projected.x - rebased.x * 1.4,
                               y: projected.y - rebased.y * 1.4)
        #expect(expected.x > revised.viewportSize.width - revised.contentSize.width * 1.4)
        #expect(expected.x < 0)
        #expect(expected.y > revised.viewportSize.height - revised.contentSize.height * 1.4)
        #expect(expected.y < 0)
        state.updatePinch(magnification: 1.4, at: projected)
        let continued = try #require(state.presentation)
        #expect(abs(continued.scale - 1.4) < 1e-8)
        #expect(abs(continued.translation.x - expected.x) < 1e-8)
        #expect(abs(continued.translation.y - expected.y) < 1e-8)
        #expect(state.focalViewportPoint == projected)
        state.cancelPinch()
        #expect(!state.isPinching)
        #expect(state.presentation == rollback.presentation)
        #expect(state.frozenReading?.anchor == frozen.anchor)
        #expect(state.focalPoint == nil)
        #expect(state.focalViewportPoint == nil)
        #expect(state.canReportBaseline)
    }
}
