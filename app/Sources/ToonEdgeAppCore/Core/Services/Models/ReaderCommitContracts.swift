import Foundation

public enum ReaderReadingEffect: Equatable, Sendable {
    case progress(ReaderProgress, sourceURL: URL, readAt: Date)
    case recentReading(RecentReadingInput)
    case recentCache(CacheMetadataInput)
}

public enum ReaderCommitOutcome: Equatable, Sendable {
    case committed, unchanged, rejected, unsupported, failed
}

@MainActor
public final class ReaderCommitAuthorization {
    public let operationID: UUID
    private let validation: @MainActor (ReaderReadingEffect) -> Bool

    public init(operationID: UUID,
                validation: @escaping @MainActor (ReaderReadingEffect) -> Bool) {
        self.operationID = operationID
        self.validation = validation
    }

    public func allowsCommit(of effect: ReaderReadingEffect) -> Bool {
        !Task.isCancelled && validation(effect)
    }
}

@MainActor
public protocol ReaderEffectsCommitting: Sendable {
    func commit(_ effect: ReaderReadingEffect,
                authorization: ReaderCommitAuthorization) async -> ReaderCommitOutcome
}

public struct ReaderAuthorizedReading: Sendable {
    public let input: RecentReadingInput
    public let authorization: ReaderCommitAuthorization

    public init(input: RecentReadingInput, authorization: ReaderCommitAuthorization) {
        self.input = input
        self.authorization = authorization
    }

    public var progressEffect: ReaderReadingEffect {
        .progress(input.progress, sourceURL: input.sourceURL, readAt: input.readAt)
    }

    public var recentEffect: ReaderReadingEffect { .recentReading(input) }

    public var cacheEffect: ReaderReadingEffect {
        .recentCache(CacheMetadataInput(sourceURL: input.sourceURL,
            seriesTitle: input.seriesTitle, chapterTitle: input.chapterTitle,
            chapterLabel: input.chapterLabel, imageCount: input.imageURLs.count,
            estimatedStorageBytes: 0, retentionState: .recent, cachedAt: input.readAt))
    }

    public func enriched(with metadata: SeriesMetadataSnapshot) -> Self {
        var enriched = input
        if let title = metadata.title, !title.isEmpty { enriched.seriesTitle = title }
        if let cover = metadata.coverImageURL { enriched.coverImageURL = cover }
        return Self(input: enriched, authorization: authorization)
    }
}
