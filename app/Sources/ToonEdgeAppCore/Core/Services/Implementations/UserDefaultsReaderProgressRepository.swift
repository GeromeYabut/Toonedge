import Foundation

public final class UserDefaultsReaderProgressRepository: ReaderProgressStoring, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let keyPrefix = "reader-progress"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func progress(for sourceURL: URL) async -> ReaderProgress? {
        guard let data = userDefaults.data(forKey: key(for: sourceURL)) else {
            return nil
        }

        return try? JSONDecoder().decode(ReaderProgress.self, from: data)
    }

    public func save(_ progress: ReaderProgress, for sourceURL: URL) async {
        guard let data = try? JSONEncoder().encode(progress) else {
            return
        }

        userDefaults.set(data, forKey: key(for: sourceURL))
    }

    private func key(for sourceURL: URL) -> String {
        "\(keyPrefix):\(sourceURL.absoluteString)"
    }
}
