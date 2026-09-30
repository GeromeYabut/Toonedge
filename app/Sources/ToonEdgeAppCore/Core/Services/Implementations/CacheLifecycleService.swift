import Foundation

/// Coordinates chapter removal without putting file operations in metadata repositories.
public struct CacheLifecycleService: CacheMetadataManaging {
    private let metadata: any CacheMetadataManaging
    private let assets: any ChapterAssetRemoving

    public init(metadata: any CacheMetadataManaging, assets: any ChapterAssetRemoving) {
        self.metadata = metadata
        self.assets = assets
    }

    public func recordCacheMetadata(_ input: CacheMetadataInput) async throws -> CacheActionResult {
        try await metadata.recordCacheMetadata(input)
    }

    public func removeCacheMetadata(for sourceURL: URL) async throws -> CacheActionResult {
        // Keep metadata visible/retryable when file deletion fails. If metadata deletion
        // fails afterwards, the idempotent file operation permits a later retry.
        try assets.removeAssets(for: sourceURL)
        return try await metadata.removeCacheMetadata(for: sourceURL)
    }

    public func updateCacheRetention(
        for sourceURL: URL, retentionState: CacheRetentionState, cachedAt: Date
    ) async throws -> CacheActionResult {
        try await metadata.updateCacheRetention(for: sourceURL, retentionState: retentionState, cachedAt: cachedAt)
    }

    public func cacheMetadataEntries() async -> [CacheMetadataEntry] {
        await metadata.cacheMetadataEntries()
    }

    public func downloadSummary() async -> DownloadSummary {
        await metadata.downloadSummary()
    }
}
