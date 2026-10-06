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
    let feedback = RecordingInteractionFeedback()
    let viewModel = SettingsViewModel(
        settingsManager: manager,
        cacheMetadataManager: MockCacheMetadataService(),
        interactionPreferences: InMemoryInteractionPreferences(),
        interactionFeedback: feedback
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
    #expect(feedback.events.isEmpty)
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

@MainActor
@Test func settingsHistoryRequestCancelAndUnconfirmedClearMakeNoCalls() async {
    let manager = SettingsHistorySpy()
    let model = settingsHistoryModel(manager)
    await model.confirmClearSearchHistory()
    model.requestClearSearchHistory()
    #expect(model.isClearSearchHistoryConfirmationPresented)
    #expect(await manager.clearCalls == 0)
    model.cancelClearSearchHistory()
    await model.confirmClearSearchHistory()
    #expect(!model.isClearSearchHistoryConfirmationPresented)
    #expect(await manager.clearCalls == 0)
}

@MainActor
@Test func settingsHistoryUnavailableAndFeedbackDismiss() async {
    let model = settingsHistoryModel(nil)
    #expect(!model.canClearSearchHistory)
    #expect(model.searchHistoryUnavailableMessage == "Search history is unavailable.")
    model.requestClearSearchHistory()
    await model.confirmClearSearchHistory()
    #expect(!model.isClearSearchHistoryConfirmationPresented)
    let available = settingsHistoryModel(SettingsHistorySpy())
    available.requestClearSearchHistory()
    await available.confirmClearSearchHistory()
    #expect(available.searchHistoryFeedback?.message == "Search history cleared.")
    #expect(available.searchHistoryFeedback?.canRetry == false)
    available.dismissSearchHistoryFeedback()
    #expect(available.searchHistoryFeedback == nil)
}

@MainActor
@Test func settingsHistorySuspendedClearSuppressesDuplicatesAndAlertDismissRace() async throws {
    let manager = SettingsHistorySpy(suspended: true)
    let model = settingsHistoryModel(manager)
    model.requestClearSearchHistory()
    let accepted = try #require(model.confirmClearSearchHistoryFromAlert())
    // Native alerts dismiss their presentation binding after accepting the button.
    model.cancelClearSearchHistory()
    #expect(model.isClearingSearchHistory)
    #expect(!model.isClearSearchHistoryConfirmationPresented)
    model.requestClearSearchHistory()
    #expect(!model.isClearSearchHistoryConfirmationPresented)
    #expect(model.confirmClearSearchHistoryFromAlert() == nil)
    await model.confirmClearSearchHistory()
    await manager.waitForClear()
    #expect(await manager.clearCalls == 1)
    await manager.finish()
    await accepted.value
    #expect(!model.isClearingSearchHistory)
    await model.confirmClearSearchHistory()
    #expect(await manager.clearCalls == 1)
}

@MainActor
@Test func settingsHistoryFailureRetryRequiresFreshConfirmationAndSharedSearchReload() async throws {
    let manager = SettingsHistorySpy(fails: true)
    try await manager.recordSearchHistory(.init(kind: .searchQuery, value: "moon", displayTitle: "moon", createdAt: Date()))
    let protectedSettings = ReaderSettings(readerCanvas: .black, displayMode: .fitScreen,
        isPageSpacingEnabled: true, brightnessAid: 0.3)
    let settings = MockSettingsService(settings: protectedSettings)
    let cacheEntry = CacheMetadataEntry(sourceURL: URL(string: "https://example.test/chapter/1")!,
        seriesTitle: "Saved", chapterTitle: "Chapter 1", chapterLabel: "1", imageCount: 2,
        estimatedStorageBytes: 42, retentionState: .retained, cachedAt: Date())
    let cache = MockCacheMetadataService(entries: [cacheEntry])
    let preferences = InMemoryInteractionPreferences(isHapticFeedbackEnabled: false)
    let feedback = RecordingInteractionFeedback()
    let model = SettingsViewModel(settingsManager: settings, cacheMetadataManager: cache,
        interactionPreferences: preferences, interactionFeedback: feedback, searchHistoryManager: manager)
    let before = SearchOverlayViewModel(searchHistoryManager: manager)
    await before.load()
    #expect(before.history.count == 1)
    model.requestClearSearchHistory()
    model.cancelClearSearchHistory()
    let cancelled = SearchOverlayViewModel(searchHistoryManager: manager)
    await cancelled.load()
    #expect(cancelled.history == before.history)
    model.requestClearSearchHistory()
    await model.confirmClearSearchHistory()
    #expect(model.searchHistoryFeedback?.message == "Couldn’t clear search history. Try again.")
    #expect(model.searchHistoryFeedback?.canRetry == true)
    #expect(!model.isClearSearchHistoryConfirmationPresented)
    let failed = SearchOverlayViewModel(searchHistoryManager: manager)
    await failed.load()
    #expect(failed.history == before.history)
    model.retryClearSearchHistory()
    #expect(model.isClearSearchHistoryConfirmationPresented)
    #expect(await manager.clearCalls == 1)
    await manager.setFails(false)
    await model.confirmClearSearchHistory()
    let cleared = SearchOverlayViewModel(searchHistoryManager: manager)
    await cleared.load()
    #expect(cleared.history.isEmpty)
    #expect(model.searchHistoryFeedback?.message == "Search history cleared.")
    #expect(!model.isClearSearchHistoryConfirmationPresented)
    #expect(settings.currentSettings() == protectedSettings)
    #expect(!preferences.isHapticFeedbackEnabled())
    #expect(feedback.events.isEmpty)
    #expect(await cache.cacheMetadataEntries() == [cacheEntry])
    // Confirming already empty history remains a successful operation.
    model.requestClearSearchHistory()
    await model.confirmClearSearchHistory()
    #expect(model.searchHistoryFeedback?.canRetry == false)
    #expect(await manager.clearCalls == 3)
}

@MainActor
private func settingsHistoryModel(_ manager: (any SearchHistoryManaging)?) -> SettingsViewModel {
    SettingsViewModel(settingsManager: MockSettingsService(), cacheMetadataManager: MockCacheMetadataService(),
        interactionPreferences: InMemoryInteractionPreferences(), searchHistoryManager: manager)
}

private actor SettingsHistorySpy: SearchHistoryManaging {
    private let history = InMemorySearchHistoryManager()
    private var fails: Bool
    private let suspended: Bool
    private var continuation: CheckedContinuation<Void, Never>?
    private var startWaiter: CheckedContinuation<Void, Never>?
    private(set) var clearCalls = 0
    init(fails: Bool = false, suspended: Bool = false) { self.fails = fails; self.suspended = suspended }
    func setFails(_ value: Bool) { fails = value }
    func recordSearchHistory(_ input: SearchHistoryInput) async throws { try await history.recordSearchHistory(input) }
    func recentSearchHistory(limit: Int) async throws -> [SearchHistoryEntry] { try await history.recentSearchHistory(limit: limit) }
    func removeSearchHistory(id: UUID) async throws { try await history.removeSearchHistory(id: id) }
    func waitForClear() async {
        if continuation != nil { return }
        await withCheckedContinuation { startWaiter = $0 }
    }
    func finish() { continuation?.resume(); continuation = nil }
    func clearSearchHistory() async throws {
        clearCalls += 1
        if suspended {
            await withCheckedContinuation {
                continuation = $0
                startWaiter?.resume(); startWaiter = nil
            }
        }
        if fails { throw URLError(.cannotWriteToFile) }
        try await history.clearSearchHistory()
    }
}
