import Foundation
import Testing
@testable import ToonEdgeAppCore

@MainActor
@Test func interactionPreferenceDefaultsEnabledAndPersists() {
    let suite = "InteractionFeedbackTests.\(UUID().uuidString)"
    defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
    let store = UserDefaultsInteractionPreferences(suiteName: suite)

    #expect(store.isHapticFeedbackEnabled())
    store.setHapticFeedbackEnabled(false)

    #expect(!UserDefaultsInteractionPreferences(suiteName: suite).isHapticFeedbackEnabled())
}

@MainActor
@Test func interactionPreferenceTreatsInvalidStoredDataAsEnabled() throws {
    let suite = "InteractionFeedbackTests.\(UUID().uuidString)"
    defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.set("invalid", forKey: UserDefaultsInteractionPreferences.hapticFeedbackEnabledKey)

    #expect(UserDefaultsInteractionPreferences(suiteName: suite).isHapticFeedbackEnabled())
}

@MainActor
@Test func disabledFeedbackRecordsNoEvents() {
    let recorder = TaskOneRecordingInteractionFeedback(isEnabled: false)

    recorder.emit(.operationSucceeded)

    #expect(recorder.events.isEmpty)
}

@MainActor
private final class TaskOneRecordingInteractionFeedback: InteractionFeedbackProviding {
    private let isEnabled: Bool
    private(set) var events: [InteractionFeedbackEvent] = []

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    func emit(_ event: InteractionFeedbackEvent) {
        guard isEnabled else { return }
        events.append(event)
    }
}
