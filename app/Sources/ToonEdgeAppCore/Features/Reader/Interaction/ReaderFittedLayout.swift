import CoreGraphics
import Foundation

public struct ReaderFittedLayout: Equatable, Sendable {
    public let geometry: ReaderChapterGeometry
    public let viewportSize: CGSize
    public let contentSize: CGSize
    public let unresolvedPageIndexes: [Int]

    public init?(sessionID: UUID, revision: UInt64, viewportSize: CGSize,
                 displayMode: ReaderDisplayMode, pageSpacing: CGFloat,
                 metadata: [ReaderPageMetadata?], placeholderHeight: CGFloat = 430) {
        guard viewportSize.width.isFinite, viewportSize.height.isFinite,
              viewportSize.width > 0, viewportSize.height > 0,
              pageSpacing.isFinite, pageSpacing >= 0,
              placeholderHeight.isFinite, placeholderHeight > 0 else { return nil }
        let widthFactor: CGFloat
        switch displayMode {
        case .fitWidth: widthFactor = 1
        case .fitScreen: widthFactor = 0.92
        }
        let width = viewportSize.width * widthFactor
        let x = (viewportSize.width - width) / 2
        var frames: [CGRect] = []
        var unresolved: [Int] = []
        frames.reserveCapacity(metadata.count)
        var y = pageSpacing
        for (index, item) in metadata.enumerated() {
            let height: CGFloat
            if let item {
                guard item.pixelWidth.isFinite, item.pixelHeight.isFinite,
                      item.pixelWidth > 0, item.pixelHeight > 0 else { return nil }
                height = width * CGFloat(item.pixelHeight / item.pixelWidth)
            } else {
                height = placeholderHeight
                unresolved.append(index)
            }
            let frame = CGRect(x: x, y: y, width: width, height: height)
            guard ReaderChapterGeometry.isUsable(frame) else { return nil }
            frames.append(frame)
            y = frame.maxY + pageSpacing
            guard y.isFinite else { return nil }
        }
        guard let geometry = ReaderChapterGeometry(sessionID: sessionID,
            revision: revision, pageFrames: frames) else { return nil }
        self.geometry = geometry
        self.viewportSize = viewportSize
        self.contentSize = CGSize(width: viewportSize.width,
            height: metadata.isEmpty ? viewportSize.height : max(viewportSize.height, y))
        self.unresolvedPageIndexes = unresolved
    }
}
