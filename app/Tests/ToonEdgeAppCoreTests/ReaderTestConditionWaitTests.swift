import Foundation
import Testing

@Test func readerTestWaitImmediatelySucceedsAtZeroTimeout() async throws {
    try await waitForReaderTestCondition("already ready", timeout: .zero) { true }
}

@Test func readerTestWaitTimeoutStopsDependentActions() async throws {
    var dependentActionRan = false
    do {
        try await waitForReaderTestCondition("fixture request", timeout: .milliseconds(30)) { false }
        dependentActionRan = true
        Issue.record("Expected timeout")
    } catch let error as ReaderTestWaitError {
        #expect(error == .timedOut("fixture request"))
    }
    #expect(!dependentActionRan)
}

@Test func readerTestWaitCancellationThrowsCancellationError() async {
    let task = Task {
        try await waitForReaderTestCondition("cancelled fixture") { false }
    }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
}
