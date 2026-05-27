import Foundation

public struct CacheStorageMeasurementService: CacheStorageMeasuring {
    private let assetCache: any ChapterAssetCaching

    public init(assetCache: any ChapterAssetCaching) {
        self.assetCache = assetCache
    }

    public func summary(for entries: [CacheMetadataEntry]) -> DownloadSummary {
        let recentCount = entries.filter { $0.retentionState == .recent }.count
        let retainedCount = entries.filter { $0.retentionState == .retained }.count
        let estimatedBytes = entries.map(\.estimatedStorageBytes).reduce(0, +)
        let measuredTotal = entries
            .map { measuredBytes(for: assetCache.chapterDirectory(for: $0.sourceURL)) }
            .reduce(0, +)
        let storageDescription = measuredTotal > 0
            ? DownloadSummary.storageDescription(for: measuredTotal, qualifier: "measured")
            : DownloadSummary.storageDescription(for: estimatedBytes)

        return DownloadSummary(
            cachedItemCount: entries.count,
            storageDescription: storageDescription,
            recentItemCount: recentCount,
            retainedItemCount: retainedCount,
            totalEstimatedBytes: estimatedBytes,
            totalMeasuredBytes: measuredTotal
        )
    }

    public func storageState(for entry: CacheMetadataEntry) -> CacheStorageState {
        let bytes = measuredBytes(for: assetCache.chapterDirectory(for: entry.sourceURL))
        if bytes > 0 {
            return .fileBacked
        }
        if entry.estimatedStorageBytes > 0 || entry.imageCount > 0 {
            return .metadataOnlyMissingFiles
        }
        return .empty
    }

    private func measuredBytes(for directory: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
