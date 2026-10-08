import Foundation

public final class UserDefaultsReaderProgressRepository: ReaderProgressStoring, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let keyPrefix = "reader-progress"

    public init(userDefaults: UserDefaults = .standard) { self.userDefaults = userDefaults }

    public func progress(for sourceURL: URL) async -> ReaderProgress? {
        guard let data = userDefaults.data(forKey: key(for: sourceURL)) else { return nil }
        return try? JSONDecoder().decode(ReaderProgress.self, from: data)
    }

    public func save(_ progress: ReaderProgress, for sourceURL: URL) async {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        userDefaults.set(data, forKey: key(for: sourceURL))
    }

    private func key(for sourceURL: URL) -> String { "\(keyPrefix):\(sourceURL.absoluteString)" }
}

extension UserDefaultsReaderProgressRepository: ReaderEffectsCommitting {
    @MainActor
    public func commit(_ effect: ReaderReadingEffect,
                       authorization: ReaderCommitAuthorization) async -> ReaderCommitOutcome {
        guard case let .progress(progress, sourceURL, _) = effect else { return .unsupported }
        guard progress.totalImageCount > 0, progress.currentImageIndex >= 0,
              progress.currentImageIndex < progress.totalImageCount,
              let data = try? JSONEncoder().encode(progress) else { return .failed }
        let capturedKey = key(for: sourceURL)
        guard authorization.allowsCommit(of: effect) else { return .rejected }
        userDefaults.set(data, forKey: capturedKey)
        return .committed
    }
}
