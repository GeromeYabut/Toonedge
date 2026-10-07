import CoreGraphics
import Foundation

public struct ReaderSemanticAnchor: Equatable, Sendable {
    public let sessionID: UUID
    public let pageIndex: Int
    public let unitPoint: CGPoint

    public init(sessionID: UUID, pageIndex: Int, unitPoint: CGPoint) {
        self.sessionID = sessionID
        self.pageIndex = pageIndex
        self.unitPoint = unitPoint
    }
}

/// Logical geometry only; revision identity does not grant progress permission.
public struct ReaderChapterGeometry: Equatable, Sendable {
    public let sessionID: UUID
    public let revision: UInt64
    public let pageFrames: [CGRect]

    public init?(sessionID: UUID, revision: UInt64, pageFrames: [CGRect]) {
        var previousBottom: CGFloat?
        for frame in pageFrames {
            guard Self.isUsable(frame) else { return nil }
            if let previousBottom, frame.minY < previousBottom { return nil }
            previousBottom = frame.maxY
        }
        self.sessionID = sessionID
        self.revision = revision
        self.pageFrames = pageFrames
    }

    public func anchor(at point: CGPoint) -> ReaderSemanticAnchor? {
        guard point.x.isFinite, point.y.isFinite,
              let index = pageFrames.firstIndex(where: { frame in
                  point.x >= frame.minX && point.x <= frame.maxX &&
                  point.y >= frame.minY && point.y <= frame.maxY
              }) else { return nil }
        let frame = pageFrames[index]
        let x = (point.x - frame.minX) / frame.width
        let y = (point.y - frame.minY) / frame.height
        guard x.isFinite, y.isFinite else { return nil }
        return ReaderSemanticAnchor(sessionID: sessionID, pageIndex: index,
            unitPoint: CGPoint(x: min(1, max(0, x)), y: min(1, max(0, y))))
    }

    public func point(for anchor: ReaderSemanticAnchor) -> CGPoint? {
        let unit = anchor.unitPoint
        guard anchor.sessionID == sessionID, pageFrames.indices.contains(anchor.pageIndex),
              unit.x.isFinite, unit.y.isFinite,
              (0...1).contains(unit.x), (0...1).contains(unit.y) else { return nil }
        let frame = pageFrames[anchor.pageIndex]
        let point = CGPoint(x: frame.minX + frame.width * unit.x,
                            y: frame.minY + frame.height * unit.y)
        guard point.x.isFinite, point.y.isFinite else { return nil }
        return point
    }

    static func isUsable(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isInfinite &&
        frame.origin.x.isFinite && frame.origin.y.isFinite &&
        frame.size.width.isFinite && frame.size.height.isFinite &&
        frame.size.width > 0 && frame.size.height > 0 &&
        frame.minX.isFinite && frame.maxX.isFinite &&
        frame.minY.isFinite && frame.maxY.isFinite &&
        frame.midX.isFinite && frame.midY.isFinite &&
        frame.maxX > frame.minX && frame.maxY > frame.minY
    }
}
