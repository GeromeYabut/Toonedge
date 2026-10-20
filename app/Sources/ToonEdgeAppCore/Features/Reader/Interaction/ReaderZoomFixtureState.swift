import CoreGraphics
import Foundation

/// Transient fixture state only. It does not authorize or perform progress writes.
public struct ReaderZoomFixtureAnchor: Equatable, Sendable {
    public let anchor: ReaderSemanticAnchor
    public let viewportPoint: CGPoint
}

public struct ReaderZoomFixtureReset: Equatable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let geometryRevision: UInt64
    public let target: ReaderZoomFixtureAnchor
}

public struct ReaderZoomFixtureState: Sendable {
    public private(set) var layout: ReaderFittedLayout
    public private(set) var presentation: ReaderPresentationTransform
    public private(set) var frozenReading: ReaderZoomFixtureAnchor?
    public private(set) var resetRequest: ReaderZoomFixtureReset?
    public private(set) var resetReconciled = false
    public private(set) var focalPoint: CGPoint?
    public private(set) var focalViewportPoint: CGPoint?

    private var committed: ReaderPresentationTransform
    private var pinchRollback: ReaderPresentationTransform?
    private var panRollback: ReaderPresentationTransform?
    private var policy = ReaderStickyBaselineZoomPolicy()
    private let pageCount: Int

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

    public init?(sessionID: UUID, viewportSize: CGSize, pageCount: Int = 80) {
        guard (1...1000).contains(pageCount),
              let layout = Self.makeLayout(sessionID: sessionID, revision: 0,
                  viewportSize: viewportSize, pageCount: pageCount),
              let presentation = ReaderPresentationTransform(layout: layout, scale: 1,
                  anchor: ReaderSemanticAnchor(sessionID: sessionID, pageIndex: 0,
                      unitPoint: CGPoint(x: 0.5, y: 0)),
                  viewportPoint: CGPoint(x: viewportSize.width / 2, y: 24)) else { return nil }
        self.layout = layout
        self.presentation = presentation
        self.committed = presentation
        self.pageCount = pageCount
    }

    private static func makeLayout(sessionID: UUID, revision: UInt64,
                                   viewportSize: CGSize, pageCount: Int) -> ReaderFittedLayout? {
        let heights = [1400.0, 650.0, 2200.0, 900.0]
        return ReaderFittedLayout(sessionID: sessionID, revision: revision,
            viewportSize: viewportSize, displayMode: .fitWidth, pageSpacing: 24,
            metadata: (0..<pageCount).map {
                ReaderPageMetadata(pixelWidth: 1000, pixelHeight: heights[$0 % heights.count])
            })
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

    private func readingSample() -> ReaderZoomFixtureAnchor? {
        for frame in layout.geometry.pageFrames {
            let intersection = frame.intersection(presentation.logicalViewport)
            guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { continue }
            guard let anchor = layout.geometry.anchor(at:
                CGPoint(x: intersection.midX, y: intersection.midY)),
                let point = presentation.viewportPoint(for: anchor) else { return nil }
            return ReaderZoomFixtureAnchor(anchor: anchor, viewportPoint: point)
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
        resetRequest = ReaderZoomFixtureReset(id: UUID(), sessionID: layout.geometry.sessionID,
            geometryRevision: layout.geometry.revision, target: target)
    }

    @discardableResult
    public mutating func acknowledgeReset(_ request: ReaderZoomFixtureReset,
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
            anchor: anchor, viewportPoint: CGPoint(x: layout.viewportSize.width / 2, y: 24))
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
    public mutating func replaceSession(sessionID: UUID, viewportSize: CGSize,
                                        pageCount: Int = 80) -> Bool {
        guard let next = Self(sessionID: sessionID, viewportSize: viewportSize, pageCount: pageCount)
        else { return false }
        self = next
        return true
    }

    @discardableResult
    public mutating func resize(viewportSize: CGSize) -> Bool {
        guard viewportSize != layout.viewportSize else { return true }
        if isPinching { cancelPinch() }
        endPan(cancelled: false)
        guard let sample = readingSample(),
              let next = Self.makeLayout(sessionID: layout.geometry.sessionID,
                  revision: layout.geometry.revision + 1, viewportSize: viewportSize,
                  pageCount: pageCount) else { return false }
        let oldSize = layout.viewportSize
        func projected(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x / oldSize.width * viewportSize.width,
                    y: point.y / oldSize.height * viewportSize.height)
        }
        guard let target = ReaderPresentationTransform(layout: next, scale: presentation.scale,
            anchor: sample.anchor, viewportPoint: projected(sample.viewportPoint)) else { return false }
        let wasResetting = resetRequest != nil
        if let frozenReading {
            self.frozenReading = ReaderZoomFixtureAnchor(anchor: frozenReading.anchor,
                viewportPoint: projected(frozenReading.viewportPoint))
        }
        layout = next
        presentation = target
        committed = target
        focalPoint = nil
        focalViewportPoint = nil
        resetRequest = nil
        resetReconciled = false
        if wasResetting { reset() }
        return true
    }
}
