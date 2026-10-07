import CoreGraphics
import Foundation

/// Pure presentation math; neither cached geometry nor scale grants progress permission.
public struct ReaderPresentationTransform: Equatable, Sendable {
    public let layout: ReaderFittedLayout
    public let scale: CGFloat
    public let translation: CGPoint
    public let logicalViewport: CGRect

    public init?(layout: ReaderFittedLayout, scale: CGFloat,
                 anchor: ReaderSemanticAnchor, viewportPoint: CGPoint) {
        let size = layout.viewportSize
        guard viewportPoint.x.isFinite, viewportPoint.y.isFinite,
              (0...size.width).contains(viewportPoint.x),
              (0...size.height).contains(viewportPoint.y),
              let point = layout.geometry.point(for: anchor) else { return nil }
        self.init(layout: layout, scale: scale,
                  proposedTranslation: CGPoint(x: viewportPoint.x - point.x * scale,
                                               y: viewportPoint.y - point.y * scale))
    }

    private init?(layout: ReaderFittedLayout, scale: CGFloat, proposedTranslation: CGPoint) {
        guard scale.isFinite, scale > 0,
              proposedTranslation.x.isFinite, proposedTranslation.y.isFinite else { return nil }
        let viewport = layout.viewportSize
        let scaled = CGSize(width: layout.contentSize.width * scale,
                            height: layout.contentSize.height * scale)
        guard ReaderChapterGeometry.isUsable(CGRect(origin: .zero, size: scaled)) else { return nil }
        let x = scaled.width <= viewport.width
            ? (viewport.width - scaled.width) / 2
            : min(0, max(viewport.width - scaled.width, proposedTranslation.x))
        let y = scaled.height <= viewport.height
            ? min(viewport.height - scaled.height, max(0, proposedTranslation.y))
            : min(0, max(viewport.height - scaled.height, proposedTranslation.y))
        let translation = CGPoint(x: x, y: y)
        let logicalViewport = CGRect(x: -x / scale, y: -y / scale,
                                     width: viewport.width / scale, height: viewport.height / scale)
        guard ReaderChapterGeometry.isUsable(logicalViewport) else { return nil }
        self.layout = layout
        self.scale = scale
        self.translation = translation
        self.logicalViewport = logicalViewport
    }

    public func viewportPoint(for anchor: ReaderSemanticAnchor) -> CGPoint? {
        guard let point = layout.geometry.point(for: anchor) else { return nil }
        let projected = CGPoint(x: point.x * scale + translation.x,
                                y: point.y * scale + translation.y)
        guard projected.x.isFinite, projected.y.isFinite else { return nil }
        return projected
    }

    public func panned(by delta: CGPoint) -> ReaderPresentationTransform? {
        guard delta.x.isFinite, delta.y.isFinite else { return nil }
        let horizontalOverflow = layout.contentSize.width * scale > layout.viewportSize.width
        let verticalOverflow = layout.contentSize.height * scale > layout.viewportSize.height
        return ReaderPresentationTransform(layout: layout, scale: scale,
            proposedTranslation: CGPoint(x: horizontalOverflow ? translation.x + delta.x : translation.x,
                                         y: verticalOverflow ? translation.y + delta.y : translation.y))
    }
}
