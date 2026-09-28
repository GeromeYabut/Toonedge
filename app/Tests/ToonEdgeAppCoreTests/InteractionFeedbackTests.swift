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
    let recorder = RecordingInteractionFeedback(isEnabled: false)

    recorder.emit(.operationSucceeded)

    #expect(recorder.events.isEmpty)
}

@MainActor
@Test func recordingFeedbackUsesCurrentPreferenceForEverySemanticEvent() {
    let preferences = InMemoryInteractionPreferences(isHapticFeedbackEnabled: true)
    let recorder = RecordingInteractionFeedback(preferences: preferences)

    recorder.emit(.selectionChanged)
    recorder.emit(.operationSucceeded)
    recorder.emit(.chapterTransitioned)
    recorder.emit(.userActionWarning)
    preferences.setHapticFeedbackEnabled(false)
    recorder.emit(.operationSucceeded)

    #expect(recorder.events == [
        .selectionChanged,
        .operationSucceeded,
        .chapterTransitioned,
        .userActionWarning
    ])
}
