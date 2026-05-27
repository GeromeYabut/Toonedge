import Foundation
import SwiftData

enum ToonEdgePersistenceModels {
    static let all: [any PersistentModel.Type] = [
        StoredSeries.self,
        StoredChapter.self,
        StoredProgress.self,
        StoredSearchHistory.self,
        StoredRecentReading.self,
        StoredCacheEntry.self
    ]
}

@Model
final class StoredSeries {
    var id: UUID
    var title: String
    var canonicalURLString: String
    var sourceDomain: String
    var coverImageURLString: String?
    var status: String
    var synopsis: String
    var latestKnownChapterLabel: String?
    var hasUnreadUpdates: Bool
    var libraryStateRaw: String
    var isCompleted: Bool
    var lastOpenedChapterID: UUID?
    var lastReadAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        title: String,
        canonicalURLString: String,
        sourceDomain: String,
        coverImageURLString: String?,
        status: String,
        synopsis: String,
        latestKnownChapterLabel: String?,
        hasUnreadUpdates: Bool,
        libraryStateRaw: String,
        isCompleted: Bool,
        lastOpenedChapterID: UUID?,
        lastReadAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.canonicalURLString = canonicalURLString
        self.sourceDomain = sourceDomain
        self.coverImageURLString = coverImageURLString
        self.status = status
        self.synopsis = synopsis
        self.latestKnownChapterLabel = latestKnownChapterLabel
        self.hasUnreadUpdates = hasUnreadUpdates
        self.libraryStateRaw = libraryStateRaw
        self.isCompleted = isCompleted
        self.lastOpenedChapterID = lastOpenedChapterID
        self.lastReadAt = lastReadAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class StoredChapter {
    var id: UUID
    var seriesID: UUID
    var title: String
    var chapterLabel: String
    var chapterNumber: Double?
    var sourceURLString: String
    var previousChapterURLString: String?
    var nextChapterURLString: String?
    var imageURLStrings: String
    var isDownloaded: Bool
    var publishedAt: Date?
    var cachedAt: Date?
    var updatedAt: Date

    init(
        id: UUID,
        seriesID: UUID,
        title: String,
        chapterLabel: String,
        chapterNumber: Double?,
        sourceURLString: String,
        previousChapterURLString: String?,
        nextChapterURLString: String?,
        imageURLStrings: String,
        isDownloaded: Bool,
        publishedAt: Date?,
        cachedAt: Date?,
        updatedAt: Date
    ) {
        self.id = id
        self.seriesID = seriesID
        self.title = title
        self.chapterLabel = chapterLabel
        self.chapterNumber = chapterNumber
        self.sourceURLString = sourceURLString
        self.previousChapterURLString = previousChapterURLString
        self.nextChapterURLString = nextChapterURLString
        self.imageURLStrings = imageURLStrings
        self.isDownloaded = isDownloaded
        self.publishedAt = publishedAt
        self.cachedAt = cachedAt
        self.updatedAt = updatedAt
    }
}

@Model
final class StoredProgress {
    var sourceURLString: String
    var id: UUID
    var chapterID: UUID?
    var currentImageIndex: Int
    var totalImageCount: Int
    var lastReadOffset: Double?
    var updatedAt: Date

    init(
        id: UUID,
        chapterID: UUID?,
        sourceURLString: String,
        currentImageIndex: Int,
        totalImageCount: Int,
        lastReadOffset: Double?,
        updatedAt: Date
    ) {
        self.id = id
        self.chapterID = chapterID
        self.sourceURLString = sourceURLString
        self.currentImageIndex = currentImageIndex
        self.totalImageCount = totalImageCount
        self.lastReadOffset = lastReadOffset
        self.updatedAt = updatedAt
    }
}

@Model
final class StoredSearchHistory {
    var value: String
    var id: UUID
    var kindRaw: String
    var displayTitle: String
    var createdAt: Date
    var lastUsedAt: Date

    init(
        id: UUID,
        kindRaw: String,
        value: String,
        displayTitle: String,
        createdAt: Date,
        lastUsedAt: Date
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.value = value
        self.displayTitle = displayTitle
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

@Model
final class StoredRecentReading {
    var seriesID: UUID
    var chapterID: UUID
    var seriesTitle: String
    var seriesURLString: String
    var sourceDomain: String
    var coverImageURLString: String?
    var chapterTitle: String
    var chapterLabel: String
    var sourceURLString: String
    var imageURLStrings: String
    var currentImageIndex: Int
    var totalImageCount: Int
    var lastReadAt: Date
    var updatedAt: Date

    init(
        seriesID: UUID,
        chapterID: UUID,
        seriesTitle: String,
        seriesURLString: String,
        sourceDomain: String,
        coverImageURLString: String?,
        chapterTitle: String,
        chapterLabel: String,
        sourceURLString: String,
        imageURLStrings: String,
        currentImageIndex: Int,
        totalImageCount: Int,
        lastReadAt: Date,
        updatedAt: Date
    ) {
        self.seriesID = seriesID
        self.chapterID = chapterID
        self.seriesTitle = seriesTitle
        self.seriesURLString = seriesURLString
        self.sourceDomain = sourceDomain
        self.coverImageURLString = coverImageURLString
        self.chapterTitle = chapterTitle
        self.chapterLabel = chapterLabel
        self.sourceURLString = sourceURLString
        self.imageURLStrings = imageURLStrings
        self.currentImageIndex = currentImageIndex
        self.totalImageCount = totalImageCount
        self.lastReadAt = lastReadAt
        self.updatedAt = updatedAt
    }
}

@Model
final class StoredCacheEntry {
    var sourceURLString: String
    var id: UUID
    var seriesTitle: String
    var chapterTitle: String
    var chapterLabel: String?
    var imageCount: Int
    var estimatedStorageBytes: Int64
    var retentionStateRaw: String
    var cachedAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        sourceURLString: String,
        seriesTitle: String,
        chapterTitle: String,
        chapterLabel: String?,
        imageCount: Int,
        estimatedStorageBytes: Int64,
        retentionStateRaw: String,
        cachedAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.sourceURLString = sourceURLString
        self.seriesTitle = seriesTitle
        self.chapterTitle = chapterTitle
        self.chapterLabel = chapterLabel
        self.imageCount = imageCount
        self.estimatedStorageBytes = estimatedStorageBytes
        self.retentionStateRaw = retentionStateRaw
        self.cachedAt = cachedAt
        self.updatedAt = updatedAt
    }
}
