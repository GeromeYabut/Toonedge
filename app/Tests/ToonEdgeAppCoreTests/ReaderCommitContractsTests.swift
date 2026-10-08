import Foundation
import Testing
@testable import ToonEdgeAppCore

func readerCommitInputFixture() -> RecentReadingInput {
    RecentReadingInput(seriesID: UUID(), chapterID: UUID(),
        seriesTitle: "Owned Fixture", seriesURL: URL(string: "https://example.com/owned")!,
        sourceDomain: "example.com", chapterTitle: "Chapter 1", chapterLabel: "1",
        sourceURL: URL(string: "https://example.com/owned/chapter-1")!,
        imageURLs: [URL(string: "https://example.com/owned/page-1.png")!],
        progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1),
        readAt: Date(timeIntervalSince1970: 100))
}

@MainActor
private final class ReaderCommitLiveState {
    var current = true
}

@MainActor
struct ReaderCommitContractsTests {
    @Test func authorizationConsultsLiveStateForEveryEffect() {
        let state = ReaderCommitLiveState()
        let input = readerCommitInputFixture()
        let authorization = ReaderCommitAuthorization(operationID: UUID()) { effect in
            state.current && effect == .progress(input.progress,
                sourceURL: input.sourceURL, readAt: input.readAt)
        }
        let reading = ReaderAuthorizedReading(input: input, authorization: authorization)
        #expect(authorization.allowsCommit(of: reading.progressEffect))
        #expect(!authorization.allowsCommit(of: reading.recentEffect))
        state.current = false
        #expect(!authorization.allowsCommit(of: reading.progressEffect))
    }

    @Test func capturedEffectsPreserveIdentityPositionAndEventDate() {
        let input = readerCommitInputFixture()
        let reading = ReaderAuthorizedReading(input: input,
            authorization: ReaderCommitAuthorization(operationID: UUID()) { _ in true })
        #expect(reading.recentEffect == .recentReading(input))
        let cache = CacheMetadataInput(sourceURL: input.sourceURL,
            seriesTitle: input.seriesTitle, chapterTitle: input.chapterTitle,
            chapterLabel: input.chapterLabel, imageCount: input.imageURLs.count,
            estimatedStorageBytes: 0, retentionState: .recent, cachedAt: input.readAt)
        #expect(reading.cacheEffect == .recentCache(cache))
    }

    @Test func enrichmentCannotRetargetCapturedReading() {
        let input = readerCommitInputFixture()
        let reading = ReaderAuthorizedReading(input: input,
            authorization: ReaderCommitAuthorization(operationID: UUID()) { _ in true })
        let cover = URL(string: "https://example.com/owned/cover.png")!
        let enriched = reading.enriched(with:
            SeriesMetadataSnapshot(title: "Enriched Fixture", coverImageURL: cover))
        #expect(enriched.input.seriesTitle == "Enriched Fixture")
        #expect(enriched.input.coverImageURL == cover)
        #expect(enriched.input.seriesID == input.seriesID)
        #expect(enriched.input.chapterID == input.chapterID)
        #expect(enriched.input.seriesURL == input.seriesURL)
        #expect(enriched.input.sourceURL == input.sourceURL)
        #expect(enriched.input.imageURLs == input.imageURLs)
        #expect(enriched.input.progress == input.progress)
        #expect(enriched.input.readAt == input.readAt)
        #expect(enriched.authorization === reading.authorization)
        #expect(reading.input.seriesTitle == "Owned Fixture")
    }
}
