import CoreGraphics
import Foundation

/// Transient presentation only; no repository or progress-write authority.
public struct ReaderZoomAnchor: Equatable, Sendable {
    public let anchor: ReaderSemanticAnchor
    public let viewportPoint: CGPoint
}

public struct ReaderZoomReset: Equatable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let geometryRevision: UInt64
    public let target: ReaderZoomAnchor
}

private struct ReaderZoomCore: Sendable {
    public private(set) var layout: ReaderFittedLayout
    public private(set) var presentation: ReaderPresentationTransform
    public private(set) var frozenReading: ReaderZoomAnchor?
    public private(set) var resetRequest: ReaderZoomReset?
    public private(set) var resetReconciled = false
    public private(set) var focalPoint: CGPoint?
    public private(set) var focalViewportPoint: CGPoint?

    private var committed: ReaderPresentationTransform
    private var pinchRollback: ReaderPresentationTransform?
    private var panRollback: ReaderPresentationTransform?
    private var pinchResetPending = false
    private var panResetPending = false
    private var policy = ReaderStickyBaselineZoomPolicy()

    public var isPinching: Bool { policy.isPinching }

    public var visibleIndexes: [Int] {
        let viewport = presentation.logicalViewport
        return layout.geometry.pageFrames.indices.filter { index in
            let frame = layout.geometry.pageFrames[index]
            return min(frame.maxX, viewport.maxX) > max(frame.minX, viewport.minX) &&
                min(frame.maxY, viewport.maxY) > max(frame.minY, viewport.minY)
        }
    }

    public var materializedIndexes: [Int] {
        ReaderPageMaterializationPolicy.indexes(in: layout.geometry,
            viewport: presentation.logicalViewport) ?? []
    }

    init?(layout: ReaderFittedLayout) {
        guard !layout.geometry.pageFrames.isEmpty,
              let presentation = ReaderPresentationTransform(layout: layout, scale: 1,
                anchor: ReaderSemanticAnchor(sessionID: layout.geometry.sessionID, pageIndex: 0,
                    unitPoint: CGPoint(x: 0.5, y: 0)),
                viewportPoint: CGPoint(x: layout.viewportSize.width / 2, y: 0)) else { return nil }
        self.layout = layout
        self.presentation = presentation
        self.committed = presentation
    }

    var focalAnchor: ReaderSemanticAnchor? {
        focalPoint.flatMap { layout.geometry.anchor(at: $0) }
    }

    private func contains(_ point: CGPoint) -> Bool {
        point.x.isFinite && point.y.isFinite &&
            (0...layout.viewportSize.width).contains(point.x) &&
            (0...layout.viewportSize.height).contains(point.y)
    }

    private func logicalPoint(at viewportPoint: CGPoint) -> CGPoint {
        CGPoint(x: (viewportPoint.x - presentation.translation.x) / presentation.scale,
                y: (viewportPoint.y - presentation.translation.y) / presentation.scale)
    }

    private func readingSample() -> ReaderZoomAnchor? {
        for frame in layout.geometry.pageFrames {
            let intersection = frame.intersection(presentation.logicalViewport)
            guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { continue }
            guard let anchor = layout.geometry.anchor(at:
                CGPoint(x: intersection.midX, y: intersection.midY)),
                let point = presentation.viewportPoint(for: anchor) else { return nil }
            return ReaderZoomAnchor(anchor: anchor, viewportPoint: point)
        }
        return nil
    }

    /// Uses existing bounded transform math even when the pinch center is in a page gap.
    private func transformed(scale: CGFloat, translation: CGPoint) -> ReaderPresentationTransform? {
        guard let frame = layout.geometry.pageFrames.first else { return nil }
        let point = CGPoint(x: frame.minX * scale + translation.x,
                            y: frame.minY * scale + translation.y)
        let bounded = CGPoint(x: min(layout.viewportSize.width, max(0, point.x)),
                              y: min(layout.viewportSize.height, max(0, point.y)))
        guard let base = ReaderPresentationTransform(layout: layout, scale: scale,
            anchor: ReaderSemanticAnchor(sessionID: layout.geometry.sessionID, pageIndex: 0,
                unitPoint: .zero), viewportPoint: bounded) else { return nil }
        return base.panned(by: CGPoint(x: translation.x - base.translation.x,
                                      y: translation.y - base.translation.y))
    }

    private mutating func freezeReadingIfNeeded() {
        if presentation.scale == 1 { frozenReading = readingSample() }
    }

    /// Replays legal samples to initialize the unchanged approved policy at an explicit
    /// accessibility selection. This does not alter its detent or breakthrough behavior.
    private static func policy(at scale: CGFloat) -> ReaderStickyBaselineZoomPolicy {
        var policy = ReaderStickyBaselineZoomPolicy()
        policy.beginPinch()
        if scale < 1 {
            policy.updatePinch(magnification: 0.9)
            policy.updatePinch(magnification:
                0.9 * ReaderStickyBaselineZoomPolicy.breakthroughRatio * Double(scale))
        } else {
            policy.updatePinch(magnification: Double(scale))
        }
        policy.endPinch()
        return policy
    }

    public mutating func beginPinch(at point: CGPoint) {
        guard contains(point), !isPinching else { return }
        pinchResetPending = resetRequest != nil && !resetReconciled
        endPan(cancelled: false)
        freezeReadingIfNeeded()
        pinchRollback = committed
        focalPoint = logicalPoint(at: point)
        focalViewportPoint = point
        resetRequest = nil
        resetReconciled = false
        policy = Self.policy(at: presentation.scale)
        policy.beginPinch()
    }

    public mutating func updatePinch(magnification: Double, at point: CGPoint) {
        guard isPinching, contains(point), magnification.isFinite, magnification > 0,
              let focalPoint else { return }
        policy.updatePinch(magnification: magnification)
        let scale = CGFloat(policy.scale)
        guard let next = transformed(scale: scale, translation:
            CGPoint(x: point.x - focalPoint.x * scale,
                    y: point.y - focalPoint.y * scale)) else { return }
        presentation = next
        focalViewportPoint = point
    }

    public mutating func endPinch() {
        guard isPinching else { return }
        policy.endPinch()
        pinchRollback = nil
        committed = presentation
        if abs(presentation.scale - 1) < 1e-12 { reset() }
    }

    public mutating func cancelPinch() {
        guard isPinching, let rollback = pinchRollback else { return }
        policy.cancelPinch()
        presentation = rollback
        committed = rollback
        pinchRollback = nil
        focalPoint = nil
        focalViewportPoint = nil
        let requiresAcknowledgement = pinchResetPending
        pinchResetPending = false
        if requiresAcknowledgement { reset() }
    }

    public mutating func inspect(scale: CGFloat, at point: CGPoint) {
        guard contains(point), scale.isFinite, (0.75...3).contains(scale), !isPinching else { return }
        if scale == 1 { reset(); return }
        endPan(cancelled: false)
        freezeReadingIfNeeded()
        let focal = logicalPoint(at: point)
        guard let next = transformed(scale: scale, translation:
            CGPoint(x: point.x - focal.x * scale, y: point.y - focal.y * scale)) else { return }
        presentation = next
        committed = next
        focalPoint = focal
        focalViewportPoint = point
        resetRequest = nil
        resetReconciled = false
    }

    public mutating func doubleTap(at point: CGPoint) {
        if presentation.scale == 1 { inspect(scale: 2, at: point) } else { reset() }
    }

    public mutating func beginPan() {
        guard !isPinching, panRollback == nil else { return }
        panResetPending = resetRequest != nil && !resetReconciled
        panRollback = committed
        resetRequest = nil
        resetReconciled = false
        focalPoint = nil
        focalViewportPoint = nil
    }

    public mutating func pan(by delta: CGPoint) {
        guard !isPinching, let next = presentation.panned(by: delta) else { return }
        recordNativeTranslation(next.translation)
    }

    public mutating func recordNativeTranslation(_ translation: CGPoint) {
        guard !isPinching, let next = transformed(scale: presentation.scale,
            translation: translation) else { return }
        let moved = abs(next.translation.x - presentation.translation.x) > 0.01 ||
            abs(next.translation.y - presentation.translation.y) > 0.01
        presentation = next
        if panRollback == nil { committed = next }
        if next.scale == 1, moved {
            frozenReading = nil
            resetRequest = nil
            resetReconciled = false
        }
    }

    public mutating func endPan(cancelled: Bool) {
        guard let rollback = panRollback else { return }
        if cancelled { presentation = rollback }
        committed = presentation
        panRollback = nil
        let requiresAcknowledgement = cancelled && panResetPending
        panResetPending = false
        if requiresAcknowledgement { reset() }
    }

    public mutating func reset() {
        let target = frozenReading ?? readingSample()
        guard let target,
              let baseline = ReaderPresentationTransform(layout: layout, scale: 1,
                  anchor: target.anchor, viewportPoint: target.viewportPoint) else { return }
        presentation = baseline
        committed = baseline
        frozenReading = target
        policy.reset()
        pinchRollback = nil
        panRollback = nil
        focalPoint = nil
        focalViewportPoint = nil
        resetReconciled = false
        resetRequest = ReaderZoomReset(id: UUID(), sessionID: layout.geometry.sessionID,
            geometryRevision: layout.geometry.revision, target: target)
    }

    @discardableResult
    public mutating func acknowledgeReset(_ request: ReaderZoomReset,
                                         measuredPoint: CGPoint) -> Bool {
        guard request == resetRequest, request.sessionID == layout.geometry.sessionID,
              request.geometryRevision == layout.geometry.revision, !isPinching,
              presentation.scale == 1, measuredPoint.x.isFinite, measuredPoint.y.isFinite,
              abs(measuredPoint.x - request.target.viewportPoint.x) <= 2,
              abs(measuredPoint.y - request.target.viewportPoint.y) <= 2 else { return false }
        resetReconciled = true
        return true
    }

    public mutating func jump(to index: Int) {
        guard layout.geometry.pageFrames.indices.contains(index) else { return }
        let anchor = ReaderSemanticAnchor(sessionID: layout.geometry.sessionID,
            pageIndex: index, unitPoint: CGPoint(x: 0.5, y: 0))
        guard let target = ReaderPresentationTransform(layout: layout, scale: 1,
            anchor: anchor, viewportPoint: CGPoint(x: layout.viewportSize.width / 2, y: 0))
        else { return }
        presentation = target
        committed = target
        policy.reset()
        frozenReading = nil
        resetRequest = nil
        resetReconciled = false
        pinchRollback = nil
        panRollback = nil
        focalPoint = nil
        focalViewportPoint = nil
    }

    @discardableResult
    mutating func relayout(_ next: ReaderFittedLayout) -> Bool {
        guard next.geometry.sessionID == layout.geometry.sessionID,
              next.geometry.revision > layout.geometry.revision,
              !next.geometry.pageFrames.isEmpty else { return false }
        let old = layout
        func project(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x / old.viewportSize.width * next.viewportSize.width,
                    y: point.y / old.viewportSize.height * next.viewportSize.height)
        }
        func remap(_ value: ReaderPresentationTransform) -> ReaderPresentationTransform? {
            let viewport = value.logicalViewport
            for frame in old.geometry.pageFrames {
                let intersection = frame.intersection(viewport)
                guard !intersection.isNull, intersection.width > 0, intersection.height > 0,
                      let anchor = old.geometry.anchor(at:
                        CGPoint(x: intersection.midX, y: intersection.midY)),
                      let point = value.viewportPoint(for: anchor) else { continue }
                return ReaderPresentationTransform(layout: next, scale: value.scale,
                    anchor: anchor, viewportPoint: project(point))
            }
            return nil
        }
        let activeAnchor = focalAnchor
        let activeViewport = focalViewportPoint
        let nextPresentation: ReaderPresentationTransform?
        if isPinching, let activeAnchor, let activeViewport {
            nextPresentation = ReaderPresentationTransform(layout: next, scale: presentation.scale,
                anchor: activeAnchor, viewportPoint: project(activeViewport))
        } else {
            nextPresentation = remap(presentation)
        }
        guard let nextPresentation, let nextCommitted = remap(committed) else { return false }
        let nextPinchRollback = pinchRollback.flatMap(remap)
        let nextPanRollback = panRollback.flatMap(remap)
        let wasResetting = resetRequest != nil
        if let frozenReading {
            self.frozenReading = ReaderZoomAnchor(anchor: frozenReading.anchor,
                viewportPoint: project(frozenReading.viewportPoint))
        }
        layout = next
        presentation = nextPresentation
        committed = nextCommitted
        pinchRollback = nextPinchRollback
        panRollback = nextPanRollback
        if isPinching, let activeViewport {
            let projected = project(activeViewport)
            // A gap or gutter has no semantic anchor. Rebase through the bounded
            // remapped presentation so the next sample continues without a jump.
            focalPoint = activeAnchor.flatMap { next.geometry.point(for: $0) }
                ?? logicalPoint(at: projected)
            focalViewportPoint = projected
        } else {
            focalPoint = nil
            focalViewportPoint = nil
        }
        resetRequest = nil
        resetReconciled = false
        if wasResetting { reset() }
        return true
    }
}

/// Production state accepts fitted real chapter geometry, including empty chapters.
public struct ReaderZoomState: Sendable {
    private var core: ReaderZoomCore?
    private var emptyLayout: ReaderFittedLayout
    public init(layout: ReaderFittedLayout) {
        self.emptyLayout = layout
        self.core = ReaderZoomCore(layout: layout)
    }
    public var layout: ReaderFittedLayout { core?.layout ?? emptyLayout }
    public var presentation: ReaderPresentationTransform? { core?.presentation }
    public var frozenReading: ReaderZoomAnchor? { core?.frozenReading }
    public var resetRequest: ReaderZoomReset? { core?.resetRequest }
    public var resetReconciled: Bool { core?.resetReconciled ?? false }
    public var focalPoint: CGPoint? { core?.focalPoint }
    public var focalAnchor: ReaderSemanticAnchor? { core?.focalAnchor }
    public var focalViewportPoint: CGPoint? { core?.focalViewportPoint }
    public var isPinching: Bool { core?.isPinching ?? false }
    public var visibleIndexes: [Int] { core?.visibleIndexes ?? [] }
    public var materializedIndexes: [Int] { core?.materializedIndexes ?? [] }
    /// Local adapter eligibility only; this is not a commit-side persistence fence.
    public var canReportBaseline: Bool {
        guard let core else { return false }
        return !core.isPinching && core.presentation.scale == 1 &&
            (core.resetRequest == nil || core.resetReconciled)
    }
    public mutating func beginPinch(at point: CGPoint) { core?.beginPinch(at: point) }
    public mutating func updatePinch(magnification: Double, at point: CGPoint) {
        core?.updatePinch(magnification: magnification, at: point)
    }
    public mutating func endPinch() { core?.endPinch() }
    public mutating func cancelPinch() { core?.cancelPinch() }
    public mutating func beginPan() { core?.beginPan() }
    public mutating func pan(by delta: CGPoint) { core?.pan(by: delta) }
    public mutating func recordNativeTranslation(_ point: CGPoint) { core?.recordNativeTranslation(point) }
    public mutating func endPan(cancelled: Bool) { core?.endPan(cancelled: cancelled) }
    public mutating func inspect(scale: CGFloat, at point: CGPoint) { core?.inspect(scale: scale, at: point) }
    public mutating func doubleTap(at point: CGPoint) { core?.doubleTap(at: point) }
    public mutating func reset() { core?.reset() }
    public mutating func jump(to index: Int) { core?.jump(to: index) }
    @discardableResult public mutating func acknowledgeReset(_ request: ReaderZoomReset,
                                                            measuredPoint: CGPoint) -> Bool {
        core?.acknowledgeReset(request, measuredPoint: measuredPoint) ?? false
    }
    @discardableResult public mutating func relayout(_ next: ReaderFittedLayout) -> Bool {
        guard next.geometry.sessionID == layout.geometry.sessionID,
              next.geometry.revision > layout.geometry.revision else { return false }
        if next.geometry.pageFrames.isEmpty {
            emptyLayout = next; core = nil; return true
        }
        if core == nil { core = ReaderZoomCore(layout: next); emptyLayout = next; return true }
        return core?.relayout(next) ?? false
    }
}
