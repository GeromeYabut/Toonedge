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
@Test func interactionPreferenceRejectsNumericValuesThatBridgeToBool() throws {
    let suite = "InteractionFeedbackTests.\(UUID().uuidString)"
    defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
    let defaults = try #require(UserDefaults(suiteName: suite))

    defaults.set(0, forKey: UserDefaultsInteractionPreferences.hapticFeedbackEnabledKey)
    #expect(UserDefaultsInteractionPreferences(suiteName: suite).isHapticFeedbackEnabled())

    defaults.set(1, forKey: UserDefaultsInteractionPreferences.hapticFeedbackEnabledKey)
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

@Test func outcomePolicyEmitsOnlyForAuthoritativeUserVisibleChanges() {
    #expect(InteractionFeedbackOutcomePolicy.cacheEvent(for: .retained) == .operationSucceeded)
    #expect(InteractionFeedbackOutcomePolicy.cacheEvent(for: .removed) == .operationSucceeded)
    #expect(InteractionFeedbackOutcomePolicy.cacheEvent(for: .recent) == nil)
    #expect(InteractionFeedbackOutcomePolicy.cacheEvent(for: .unchanged) == nil)
    #expect(InteractionFeedbackOutcomePolicy.cacheEvent(for: .notFound) == nil)

    let updates = LibraryUpdateRefreshResult(checkedCount: 3, updatedCount: 1, failedCount: 0)
    let noUpdates = LibraryUpdateRefreshResult(checkedCount: 3, updatedCount: 0, failedCount: 0)
    #expect(InteractionFeedbackOutcomePolicy.updateEvent(for: updates, userInitiated: true) == .operationSucceeded)
    #expect(InteractionFeedbackOutcomePolicy.updateEvent(for: updates, userInitiated: false) == nil)
    #expect(InteractionFeedbackOutcomePolicy.updateEvent(for: noUpdates, userInitiated: true) == nil)

    #expect(InteractionFeedbackOutcomePolicy.selectionEvent(valueChanged: true) == .selectionChanged)
    #expect(InteractionFeedbackOutcomePolicy.selectionEvent(valueChanged: false) == nil)
    #expect(InteractionFeedbackOutcomePolicy.invalidInputEvent(validationIsVisible: true) == .userActionWarning)
    #expect(InteractionFeedbackOutcomePolicy.invalidInputEvent(validationIsVisible: false) == nil)
}
