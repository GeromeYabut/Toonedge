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
        cacheMetadataManager: MockCacheMetadataService()
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

@MainActor
@Test(arguments: [
    (LibraryUpdateRefreshResult(checkedCount: 3, updatedCount: 1, failedCount: 0), "Found updates for 1 series."),
    (LibraryUpdateRefreshResult(checkedCount: 3, updatedCount: 0, failedCount: 0), "No new chapters found."),
    (LibraryUpdateRefreshResult(checkedCount: 3, updatedCount: 0, failedCount: 2), "Checked 3 series; 2 could not be refreshed.")
])
func settingsUpdateFeedbackCoversSuccessNoUpdateAndFailure(
    result: LibraryUpdateRefreshResult,
    expectedMessage: String
) async {
    let viewModel = SettingsViewModel(
        settingsManager: MockSettingsService(),
        cacheMetadataManager: MockCacheMetadataService(),
        updateRefreshService: MockLibraryUpdateRefreshService(result: result)
    )

    await viewModel.refreshUpdates()

    #expect(viewModel.updateMessage == expectedMessage)
    #expect(!viewModel.isCheckingForUpdates)
}
