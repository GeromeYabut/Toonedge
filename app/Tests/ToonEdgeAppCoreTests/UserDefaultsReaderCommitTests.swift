import Foundation
import Testing
@testable import ToonEdgeAppCore

@MainActor
final class ReaderPrecommitPause {
    private var paused = false
    private var released = false
    private var waiter: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    func pause() async {
        guard !released else { return }
        paused = true
        waiter?.resume(); waiter = nil
        await withCheckedContinuation { releaseContinuation = $0 }
    }
    func waitUntilPaused() async {
        if paused { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func release() {
        released = true
        releaseContinuation?.resume(); releaseContinuation = nil
        waiter?.resume(); waiter = nil
    }
}

@MainActor
final class DelayedUserDefaultsReaderCommit: ReaderEffectsCommitting {
    let backend: UserDefaultsReaderProgressRepository
    let pause: ReaderPrecommitPause
    init(backend: UserDefaultsReaderProgressRepository, pause: ReaderPrecommitPause) {
        self.backend = backend; self.pause = pause
    }
    func commit(_ effect: ReaderReadingEffect,
                authorization: ReaderCommitAuthorization) async -> ReaderCommitOutcome {
        await pause.pause()
        return await backend.commit(effect, authorization: authorization)
    }
}

@MainActor
struct UserDefaultsReaderCommitTests {
    @Test func startedButInvalidatedSaveCannotMutateRealStorage() async throws {
        for invalidate in 0..<5 {
            let name = "ToonEdge.ReaderCommit.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: name))
            defer { defaults.removePersistentDomain(forName: name) }
            let backend = UserDefaultsReaderProgressRepository(userDefaults: defaults)
            let fixture = try ReaderProgressGateFixture()
            let reading = try fixture.reading()
            let pause = ReaderPrecommitPause()
            let writer = DelayedUserDefaultsReaderCommit(backend: backend, pause: pause)
            let task = Task { await writer.commit(reading.progressEffect,
                authorization: reading.authorization) }
            defer { pause.release(); task.cancel() }
            await pause.waitUntilPaused()
            switch invalidate {
            case 0:
                let token = try #require(fixture.gate.coordinator.request).token
                fixture.gate.transition { _ = $0.beginGesture(from: token,
                    epochID: UUID(), requestID: UUID()) }
            case 1:
                fixture.gate.transition { _ = $0.reset(installationID: $0.installationID,
                    epochID: UUID(), requestID: UUID()) }
            case 2:
                fixture.gate.transition { _ = $0.suspend(installationID: $0.installationID,
                    epochID: UUID()) }
            case 3: fixture.gate.retireInstallation()
            default: _ = try fixture.reading()
            }
            pause.release()
            let outcome = await task.value
            #expect(outcome == .rejected)
            #expect(await backend.progress(for: reading.input.sourceURL) == nil)
            #expect((defaults.persistentDomain(forName: name) ?? [:]).keys.filter {
                $0.hasPrefix("reader-progress:")
            }.isEmpty)
        }
    }

    @Test func completedValidSaveRemainsAfterInspectionStarts() async throws {
        let name = "ToonEdge.ReaderCommit.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let backend = UserDefaultsReaderProgressRepository(userDefaults: defaults)
        let fixture = try ReaderProgressGateFixture()
        let reading = try fixture.reading()
        let outcome = await backend.commit(reading.progressEffect,
            authorization: reading.authorization)
        #expect(outcome == .committed)
        let token = try #require(fixture.gate.coordinator.request).token
        fixture.gate.transition { _ = $0.beginGesture(from: token,
            epochID: UUID(), requestID: UUID()) }
        #expect(await backend.progress(for: reading.input.sourceURL) == reading.input.progress)
        let rejected = await backend.commit(reading.progressEffect,
            authorization: reading.authorization)
        #expect(rejected == .rejected)
    }

    @Test func resetRecoveryAndBackwardReadingSaveWithFreshAuthority() async throws {
        let name = "ToonEdge.ReaderCommit.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let backend = UserDefaultsReaderProgressRepository(userDefaults: defaults)
        let fixture = try ReaderProgressGateFixture(pageCount: 3)
        try fixture.move(to: 2)
        let end = try fixture.reading()
        #expect(await backend.commit(end.progressEffect, authorization: end.authorization) == .committed)
        fixture.gate.transition { _ = $0.reset(installationID: $0.installationID,
            epochID: UUID(), requestID: UUID()) }
        #expect(fixture.gate.admit(operationID: UUID(), readAt: Date()) == nil)
        try fixture.acknowledgeCurrent()
        try fixture.move(to: 0)
        let back = try fixture.reading()
        #expect(await backend.commit(back.progressEffect, authorization: back.authorization) == .committed)
        #expect(await backend.progress(for: back.input.sourceURL)?.currentImageIndex == 0)
        let reconstructed = UserDefaultsReaderProgressRepository(userDefaults: defaults)
        #expect(await reconstructed.progress(for: back.input.sourceURL) == back.input.progress)
    }

    @Test func metadataEffectsAreUnsupportedAndWrongTargetIsRejected() async throws {
        let name = "ToonEdge.ReaderCommit.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let backend = UserDefaultsReaderProgressRepository(userDefaults: defaults)
        let fixture = try ReaderProgressGateFixture()
        let reading = try fixture.reading()
        #expect(await backend.commit(reading.recentEffect,
            authorization: reading.authorization) == .unsupported)
        #expect(await backend.commit(reading.cacheEffect,
            authorization: reading.authorization) == .unsupported)
        let wrong = ReaderReadingEffect.progress(reading.input.progress,
            sourceURL: URL(string: "https://example.com/other/chapter-2")!, readAt: reading.input.readAt)
        #expect(await backend.commit(wrong, authorization: reading.authorization) == .rejected)
        #expect(await backend.progress(for: reading.input.sourceURL) == nil)
    }

    @Test func invalidProgressCannotWriteAndLegacyEncodingRemainsCompatible() async throws {
        let name = "ToonEdge.ReaderCommit.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let backend = UserDefaultsReaderProgressRepository(userDefaults: defaults)
        let input = readerCommitInputFixture()
        let authorization = ReaderCommitAuthorization(operationID: UUID()) { _ in true }
        let invalid = ReaderReadingEffect.progress(
            ReaderProgress(currentImageIndex: 2, totalImageCount: 1),
            sourceURL: input.sourceURL, readAt: input.readAt)
        #expect(await backend.commit(invalid, authorization: authorization) == .failed)
        #expect(await backend.progress(for: input.sourceURL) == nil)
        let valid = ReaderReadingEffect.progress(input.progress,
            sourceURL: input.sourceURL, readAt: input.readAt)
        #expect(await backend.commit(valid, authorization: authorization) == .committed)
        let bytes = try #require(defaults.data(forKey: "reader-progress:\(input.sourceURL.absoluteString)"))
        #expect(try JSONDecoder().decode(ReaderProgress.self, from: bytes) == input.progress)
    }
}
