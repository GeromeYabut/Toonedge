import CoreGraphics
import Foundation

public struct ReaderSemanticPresentation: Equatable, Sendable {
    public let scale: CGFloat
    public let anchor: ReaderSemanticAnchor
    public let viewportPoint: CGPoint

    public init?(scale: CGFloat, anchor: ReaderSemanticAnchor, viewportPoint: CGPoint) {
        guard scale.isFinite, (0.75...3).contains(scale),
              viewportPoint.x.isFinite, viewportPoint.y.isFinite else { return nil }
        self.scale = scale; self.anchor = anchor; self.viewportPoint = viewportPoint
    }

    public func reproject(in layout: ReaderFittedLayout) -> ReaderPresentationTransform? {
        guard let transform = ReaderPresentationTransform(layout: layout, scale: scale,
            anchor: anchor, viewportPoint: viewportPoint),
            let actual = transform.viewportPoint(for: anchor),
            Self.withinTolerance(actual, viewportPoint) else { return nil }
        return transform
    }

    static func withinTolerance(_ actual: CGPoint, _ required: CGPoint) -> Bool {
        actual.x.isFinite && actual.y.isFinite && required.x.isFinite && required.y.isFinite &&
            abs(actual.x - required.x) <= 2 && abs(actual.y - required.y) <= 2
    }

    public static func capture(_ transform: ReaderPresentationTransform,
                               preferredAnchor: ReaderSemanticAnchor) -> Self? {
        let layout = transform.layout
        guard layout.geometry.point(for: preferredAnchor) != nil else { return nil }
        guard let intersection = layout.geometry.pageFrames.lazy.map({
            $0.intersection(transform.logicalViewport)
        }).first(where: { !$0.isNull && $0.width > 0 && $0.height > 0 }) else { return nil }
        let viewport = CGRect(origin: .zero, size: layout.viewportSize)
        var anchor = preferredAnchor
        var point = transform.viewportPoint(for: anchor)
        if point.map({ $0.x >= 0 && $0.x <= viewport.width &&
                       $0.y >= 0 && $0.y <= viewport.height }) != true {
            guard let visibleAnchor = layout.geometry.anchor(at:
                CGPoint(x: intersection.midX, y: intersection.midY)) else { return nil }
            anchor = visibleAnchor
            point = transform.viewportPoint(for: anchor)
        }
        guard let point, let result = Self(scale: transform.scale, anchor: anchor,
            viewportPoint: point), let rebuilt = result.reproject(in: layout),
            abs(rebuilt.translation.x - transform.translation.x) <= 1e-7,
            abs(rebuilt.translation.y - transform.translation.y) <= 1e-7 else { return nil }
        return result
    }

    public static func bootstrap(index: Int, in layout: ReaderFittedLayout) -> Self? {
        let anchor = ReaderSemanticAnchor(sessionID: layout.geometry.sessionID,
            pageIndex: index, unitPoint: CGPoint(x: 0.5, y: 0))
        guard let transform = ReaderPresentationTransform(layout: layout, scale: 1,
            anchor: anchor, viewportPoint: CGPoint(x: layout.viewportSize.width / 2, y: 0))
        else { return nil }
        return capture(transform, preferredAnchor: anchor)
    }
}
