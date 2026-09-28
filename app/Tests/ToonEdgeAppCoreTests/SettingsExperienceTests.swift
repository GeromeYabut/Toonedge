import Foundation
import Testing
@testable import ToonEdgeAppCore

@Test func readerSettingsSupportsAccessibilityLayout() {
    let layout = ReaderSettingsLayout(dynamicTypeIsAccessibility: true)

    #expect(layout.usesScrollingContent)
    #expect(layout.supportsMediumDetent)
    #expect(layout.supportsLargeDetent)
    #expect(layout.showsDoneAction)
}

@Test func readerCanvasRowsAreBorderlessAndExposeOneSelectionCheckmark() {
    let selected = ReaderCanvasRowPresentation(canvas: .paper, selectedCanvas: .paper)
    let unselected = ReaderCanvasRowPresentation(canvas: .charcoal, selectedCanvas: .paper)

    #expect(!selected.usesBorder)
    #expect(selected.showsCheckmark)
    #expect(!unselected.showsCheckmark)
    #expect(selected.minimumActionSize == 44)
    #expect(selected.accessibilityValue == "Selected")
    #expect(unselected.accessibilityValue == "Not selected")
}

@Test func readerSettingsPersistAcrossRepositoryReconstruction() async throws {
    let suiteName = "ToonEdgeSettingsTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let expected = ReaderSettings(
        readerCanvas: .paper,
        displayMode: .fitScreen,
        isPageSpacingEnabled: true,
        brightnessAid: 0.42
    )
    let writer = UserDefaultsSettingsRepository(userDefaults: defaults)
    await writer.updateSettings(expected)

    let reader = UserDefaultsSettingsRepository(userDefaults: defaults)
    #expect(reader.currentSettings() == expected)
}

@MainActor
@Test func staleReaderSettingsSnapshotCannotOverwriteDisabledHapticPreference() async throws {
    let suiteName = "ToonEdgeIndependentInteractionSettings-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let interactionPreferences = UserDefaultsInteractionPreferences(suiteName: suiteName)
    let readerSettings = UserDefaultsSettingsRepository(userDefaults: defaults)
    interactionPreferences.setHapticFeedbackEnabled(false)

    var staleSnapshot = readerSettings.currentSettings()
    staleSnapshot.displayMode = .fitScreen
    await readerSettings.updateSettings(staleSnapshot)

    let reconstructedInteractionPreferences = UserDefaultsInteractionPreferences(suiteName: suiteName)
    let reconstructedReaderSettings = UserDefaultsSettingsRepository(userDefaults: defaults)
    #expect(!reconstructedInteractionPreferences.isHapticFeedbackEnabled())
    #expect(reconstructedReaderSettings.currentSettings().displayMode == .fitScreen)
}

@MainActor
@Test func settingsHapticToggleUsesIndependentPreferenceAndDisablesFeedbackImmediately() {
    let preferences = InMemoryInteractionPreferences(isHapticFeedbackEnabled: true)
    let feedback = RecordingInteractionFeedback(preferences: preferences)
    let viewModel = SettingsViewModel(
        settingsManager: MockSettingsService(),
        cacheMetadataManager: MockCacheMetadataService(),
        interactionPreferences: preferences
    )

    #expect(viewModel.isHapticFeedbackEnabled)
    viewModel.setHapticFeedbackEnabled(false)
    feedback.emit(.selectionChanged)

    #expect(!viewModel.isHapticFeedbackEnabled)
    #expect(!preferences.isHapticFeedbackEnabled())
    #expect(feedback.events.isEmpty)
    #expect(viewModel.settings == .default)
}

@Test func readerSettingsFallBackFieldByFieldForInvalidStoredValues() throws {
    let suiteName = "ToonEdgeInvalidSettingsTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set("not-a-canvas", forKey: UserDefaultsSettingsRepository.Key.readerCanvas)
    defaults.set(ReaderDisplayMode.fitScreen.rawValue, forKey: UserDefaultsSettingsRepository.Key.displayMode)
    defaults.set(true, forKey: UserDefaultsSettingsRepository.Key.pageSpacing)
    defaults.set(4.0, forKey: UserDefaultsSettingsRepository.Key.brightnessAid)

    let settings = UserDefaultsSettingsRepository(userDefaults: defaults).currentSettings()
    #expect(settings.readerCanvas == .charcoal)
    #expect(settings.displayMode == .fitScreen)
    #expect(settings.isPageSpacingEnabled)
    #expect(settings.brightnessAid == 0)
}

@MainActor
@Test func settingsViewModelPersistsEveryReaderControl() async {
    let manager = MockSettingsService()
    let viewModel = SettingsViewModel(
        settingsManager: manager,
        cacheMetadataManager: MockCacheMetadataService(),
        interactionPreferences: InMemoryInteractionPreferences()
    )

    await viewModel.setCanvas(.black)
    await viewModel.setDisplayMode(.fitScreen)
    await viewModel.setPageSpacing(true)
    await viewModel.setBrightness(0.3)

    #expect(manager.currentSettings() == ReaderSettings(
        readerCanvas: .black,
        displayMode: .fitScreen,
        isPageSpacingEnabled: true,
        brightnessAid: 0.3
    ))
}

@Test func settingsUpdateFeedbackDistinguishesAllOutcomes() {
    let noSavedSeries = SettingsUpdateFeedback(result: .init(checkedCount: 0, updatedCount: 0, failedCount: 0))
    let noChanges = SettingsUpdateFeedback(result: .init(checkedCount: 4, updatedCount: 0, failedCount: 0))
    let updatesFound = SettingsUpdateFeedback(result: .init(checkedCount: 4, updatedCount: 2, failedCount: 0))
    let partial = SettingsUpdateFeedback(result: .init(checkedCount: 4, updatedCount: 2, failedCount: 1))
    let partialWithoutUpdates = SettingsUpdateFeedback(result: .init(checkedCount: 3, updatedCount: 0, failedCount: 2))
    let totalFailure = SettingsUpdateFeedback(result: .init(checkedCount: 4, updatedCount: 0, failedCount: 4))

    #expect(noSavedSeries == .noSavedSeries)
    #expect(noSavedSeries.message == "No saved series to check.")
    #expect(noChanges == .noChanges)
    #expect(noChanges.message == "No new chapters found.")
    #expect(updatesFound == .updatesFound(count: 2))
    #expect(updatesFound.message == "Found updates for 2 series.")
    #expect(partial == .partial(updated: 2, failed: 1))
    #expect(partial.message == "Found updates for 2 series; 1 series could not be refreshed.")
    #expect(partialWithoutUpdates == .partial(updated: 0, failed: 2))
    #expect(partialWithoutUpdates.message == "No updates found; 2 series could not be refreshed.")
    #expect(totalFailure == .totalFailure(failed: 4))
    #expect(totalFailure.message == "Could not refresh 4 series.")
}

@MainActor
@Test func settingsUpdateFeedbackReportsUnavailableService() async {
    let viewModel = SettingsViewModel(
        settingsManager: MockSettingsService(),
        cacheMetadataManager: MockCacheMetadataService(),
        interactionPreferences: InMemoryInteractionPreferences()
    )

    await viewModel.refreshUpdates()

    #expect(viewModel.updateFeedback == .unavailable)
    #expect(!viewModel.isCheckingForUpdates)
}

@MainActor
@Test func settingsUpdateCheckSuppressesDuplicateRequests() async {
    let service = SuspendedSettingsUpdateRefreshService()
    let feedback = RecordingInteractionFeedback()
    let viewModel = SettingsViewModel(
        settingsManager: MockSettingsService(),
        cacheMetadataManager: MockCacheMetadataService(),
        interactionPreferences: InMemoryInteractionPreferences(),
        interactionFeedback: feedback,
        updateRefreshService: service
    )

    let firstCheck = Task { await viewModel.refreshUpdates() }
    while await service.refreshCallCount == 0 {
        await Task.yield()
    }

    await viewModel.refreshUpdates()

    #expect(await service.refreshCallCount == 1)
    await service.finish()
    await firstCheck.value
    #expect(viewModel.updateFeedback == .noChanges)
    #expect(feedback.events.isEmpty)
}

@MainActor
@Test func explicitSettingsUpdateFoundEmitsOnceWhileNoUpdateRemainsSilent() async {
    let feedback = RecordingInteractionFeedback()
    let updatedViewModel = SettingsViewModel(
        settingsManager: MockSettingsService(),
        cacheMetadataManager: MockCacheMetadataService(),
        interactionPreferences: InMemoryInteractionPreferences(),
        interactionFeedback: feedback,
        updateRefreshService: MockLibraryUpdateRefreshService(
            result: .init(checkedCount: 2, updatedCount: 1, failedCount: 0)
        )
    )

    await updatedViewModel.refreshUpdates()
    #expect(feedback.events == [.operationSucceeded])

    feedback.reset()
    let noUpdateViewModel = SettingsViewModel(
        settingsManager: MockSettingsService(),
        cacheMetadataManager: MockCacheMetadataService(),
        interactionPreferences: InMemoryInteractionPreferences(),
        interactionFeedback: feedback,
        updateRefreshService: MockLibraryUpdateRefreshService(
            result: .init(checkedCount: 2, updatedCount: 0, failedCount: 0)
        )
    )
    await noUpdateViewModel.refreshUpdates()
    #expect(feedback.events.isEmpty)
}

private actor SuspendedSettingsUpdateRefreshService: LibraryUpdateRefreshing {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var refreshCallCount = 0

    func finish() {
        continuation?.resume()
        continuation = nil
    }

    func refreshUpdates() async -> LibraryUpdateRefreshResult {
        refreshCallCount += 1
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        return LibraryUpdateRefreshResult(checkedCount: 2, updatedCount: 0, failedCount: 0)
    }
}
