import Foundation

enum ReaderTestWaitError: Error, Equatable, Sendable {
    case timedOut(String)
}

func waitForReaderTestCondition(
    _ description: String,
    timeout: Duration = .seconds(10),
    isolation: isolated (any Actor)? = #isolation,
    condition: () async -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while true {
        try Task.checkCancellation()
        if await condition() { return }
        guard ContinuousClock.now < deadline else {
            throw ReaderTestWaitError.timedOut(description)
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}
