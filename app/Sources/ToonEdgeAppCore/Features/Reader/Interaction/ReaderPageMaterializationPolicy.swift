import CoreGraphics
import Foundation

/// Desired indexes only. Does not create containers or grant progress permission.
public enum ReaderPageMaterializationPolicy {
    public static func indexes(in geometry: ReaderChapterGeometry, viewport: CGRect) -> [Int]? {
        guard ReaderChapterGeometry.isUsable(viewport) else { return nil }
        let frames = geometry.pageFrames
        guard !frames.isEmpty else { return [] }
        let visible = frames.indices.filter { index in
            let frame = frames[index]
            return min(frame.maxX, viewport.maxX) > max(frame.minX, viewport.minX) &&
                   min(frame.maxY, viewport.maxY) > max(frame.minY, viewport.minY)
        }
        if let first = visible.first, let last = visible.last {
            var selected = visible
            if first > 0 { selected.append(first - 1) }
            if last + 1 < frames.count { selected.append(last + 1) }
            return Array(Set(selected)).sorted()
        }

        var nearest = 0
        var nearestDistance = CGFloat.infinity
        for index in frames.indices {
            let frame = frames[index]
            let distance: CGFloat
            if frame.maxY < viewport.minY {
                distance = viewport.minY - frame.maxY
            } else if frame.minY > viewport.maxY {
                distance = frame.minY - viewport.maxY
            } else {
                distance = 0
            }
            guard distance.isFinite else { return nil }
            if distance < nearestDistance {
                nearest = index
                nearestDistance = distance
            }
        }
        let direction = viewport.midY >= frames[nearest].midY ? 1 : -1
        let preferred = nearest + direction
        let opposite = nearest - direction
        let neighbor = frames.indices.contains(preferred) ? preferred : opposite
        var selected = [nearest]
        if frames.indices.contains(neighbor) { selected.append(neighbor) }
        return selected.sorted()
    }
}
