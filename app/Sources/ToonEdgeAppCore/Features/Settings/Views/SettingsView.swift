import SwiftUI

public enum SettingsUpdateFeedback: Equatable, Sendable {
    case noSavedSeries
    case noChanges
    case updatesFound(count: Int)
    case partial(updated: Int, failed: Int)
    case totalFailure(failed: Int)
    case unavailable

    public init(result: LibraryUpdateRefreshResult) {
        if result.checkedCount == 0 {
            self = .noSavedSeries
        } else if result.updatedCount == 0, result.failedCount >= result.checkedCount {
            self = .totalFailure(failed: result.failedCount)
        } else if result.failedCount > 0 {
            self = .partial(updated: result.updatedCount, failed: result.failedCount)
        } else if result.updatedCount > 0 {
            self = .updatesFound(count: result.updatedCount)
        } else {
            self = .noChanges
        }
    }

    public var message: String {
        switch self {
        case .noSavedSeries:
            "No saved series to check."
        case .noChanges:
            "No new chapters found."
        case let .updatesFound(count):
            "Found updates for \(count) series."
        case let .partial(updated, failed):
            updated == 0
                ? "No updates found; \(failed) series could not be refreshed."
                : "Found updates for \(updated) series; \(failed) series could not be refreshed."
        case let .totalFailure(failed):
            "Could not refresh \(failed) series."
        case .unavailable:
            "Update checking is unavailable."
        }
    }
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public private(set) var settings: ReaderSettings
    @Published public private(set) var storageSummary: DownloadSummary
    @Published public private(set) var isCheckingForUpdates = false
    @Published public private(set) var updateFeedback: SettingsUpdateFeedback?

    private let settingsManager: any SettingsManaging
    private let cacheMetadataManager: any CacheMetadataManaging
    private let storageMeasurementService: (any CacheStorageMeasuring)?
    private let updateRefreshService: (any LibraryUpdateRefreshing)?

    public init(
        settingsManager: any SettingsManaging,
        cacheMetadataManager: any CacheMetadataManaging,
        storageMeasurementService: (any CacheStorageMeasuring)? = nil,
        updateRefreshService: (any LibraryUpdateRefreshing)? = nil
    ) {
        self.settingsManager = settingsManager
        self.cacheMetadataManager = cacheMetadataManager
        self.storageMeasurementService = storageMeasurementService
        self.updateRefreshService = updateRefreshService
        self.settings = settingsManager.currentSettings()
        self.storageSummary = DownloadSummary(cachedItemCount: 0, storageDescription: "Loading")
    }

    public func loadStorage() async {
        let entries = await cacheMetadataManager.cacheMetadataEntries()
        if let storageMeasurementService {
            storageSummary = storageMeasurementService.summary(for: entries)
        } else {
            storageSummary = await cacheMetadataManager.downloadSummary()
        }
    }

    public func setDisplayMode(_ mode: ReaderDisplayMode) async {
        settings.displayMode = mode
        await settingsManager.updateSettings(settings)
    }

    public func setCanvas(_ canvas: ReaderCanvas) async {
        settings.readerCanvas = canvas
        await settingsManager.updateSettings(settings)
    }

    public func setPageSpacing(_ enabled: Bool) async {
        settings.isPageSpacingEnabled = enabled
        await settingsManager.updateSettings(settings)
    }

    public func setBrightness(_ brightness: Double) async {
        settings.brightnessAid = min(0.75, max(0, brightness))
        await settingsManager.updateSettings(settings)
    }

    public func refreshUpdates() async {
        guard !isCheckingForUpdates else { return }
        guard let updateRefreshService else {
            updateFeedback = .unavailable
            return
        }
        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }
        let result = await updateRefreshService.refreshUpdates()
        updateFeedback = SettingsUpdateFeedback(result: result)
    }
}

public struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let onShowDownloads: () -> Void

    public init(dependencies: AppDependencies, onShowDownloads: @escaping () -> Void = {}) {
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(
            settingsManager: dependencies.settingsService,
            cacheMetadataManager: dependencies.cacheMetadataService,
            storageMeasurementService: dependencies.cacheStorageMeasurementService,
            updateRefreshService: dependencies.updateRefreshService
        ))
        self.onShowDownloads = onShowDownloads
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
                    settingsSection("Reader Preferences") {
                        TEEditorialGroup(SettingsPreference.allCases, spacing: 0, separatorInset: 0) { preference in
                            preferenceRow(preference)
                        }
                    }

                    settingsSection("Storage Management") {
                        TEEditorialGroup([SettingsUtility.storage]) { _ in
                            Button(action: onShowDownloads) {
                                storageDisclosureLabel
                            }
                            .buttonStyle(.plain)
                            .modifier(TEEditorialRowStyle())
                            .accessibilityLabel("Downloads")
                            .accessibilityValue("\(storageItemDescription), \(viewModel.storageSummary.storageDescription)")
                            .accessibilityHint("Opens downloaded data management")
                            .accessibilityIdentifier("settings.manageDownloads")
                        }
                    }

                    settingsSection("New Chapters") {
                        VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
                            TEEditorialGroup([SettingsUtility.updateCheck]) { _ in
                                Button {
                                    Task { await viewModel.refreshUpdates() }
                                } label: {
                                    Label(
                                        viewModel.isCheckingForUpdates ? "Checking…" : "Check for New Chapters",
                                        systemImage: "arrow.clockwise"
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .modifier(TEEditorialRowStyle())
                                .disabled(viewModel.isCheckingForUpdates)
                                .accessibilityIdentifier("settings.checkUpdates")
                            }

                            if !viewModel.isCheckingForUpdates, let feedback = viewModel.updateFeedback {
                                Text(feedback.message)
                                    .font(ToonEdgeTypography.caption)
                                    .foregroundStyle(ToonEdgeColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, ToonEdgeSpacing.medium)
                                    .accessibilityIdentifier("settings.updateResult")
                            }
                        }
                    }

                    settingsSection("About ToonEdge") {
                        TEEditorialGroup([SettingsUtility.about]) { _ in
                            VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                                Text("ToonEdge \(appVersion)")
                                    .font(ToonEdgeTypography.body.weight(.semibold))
                                Text("A local-first reading browser. Content remains on its source website, and protected viewers stay in the browser.")
                                    .font(ToonEdgeTypography.caption)
                                    .foregroundStyle(ToonEdgeColor.textSecondary)
                                Text("Support, privacy, and legal details are available with the release information for this build.")
                                    .font(ToonEdgeTypography.caption)
                                    .foregroundStyle(ToonEdgeColor.textSecondary)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .modifier(TEEditorialRowStyle())
                        }
                    }
                }
                .padding(ToonEdgeSpacing.large)
                .padding(.bottom, ToonEdgeSpacing.xlarge)
            }
            .navigationTitle("Settings")
            .task { await viewModel.loadStorage() }
            .toonEdgeScreen()
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
            Text(title).font(ToonEdgeTypography.sectionTitle)
            content()
        }
    }

    @ViewBuilder
    private func preferenceRow(_ preference: SettingsPreference) -> some View {
        switch preference {
        case .readerFit:
            adaptivePicker(
                title: "Reader Fit",
                selection: displayModeBinding,
                values: ReaderDisplayMode.allCases,
                label: { $0.title },
                accessibilityIdentifier: "settings.readerFit"
            )
        case .canvas:
            adaptivePicker(
                title: "Canvas",
                selection: canvasBinding,
                values: [.charcoal, .black, .paper],
                label: { $0.title },
                accessibilityIdentifier: "settings.canvas"
            )
        case .pageSpacing:
            Toggle("Page Spacing", isOn: pageSpacingBinding)
                .accessibilityIdentifier("settings.pageSpacing")
                .modifier(TEEditorialRowStyle())
        case .brightness:
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                Text("Brightness Aid")
                    .font(ToonEdgeTypography.body.weight(.semibold))
                Slider(value: brightnessBinding, in: 0...0.75)
                    .tint(ToonEdgeColor.accent)
                    .accessibilityIdentifier("settings.brightness")
            }
            .modifier(TEEditorialRowStyle())
        }
    }

    @ViewBuilder
    private func adaptivePicker<Value: Hashable>(
        title: String,
        selection: Binding<Value>,
        values: [Value],
        label: @escaping (Value) -> String,
        accessibilityIdentifier: String
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { value in
                    Text(label(value)).tag(value)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier(accessibilityIdentifier)
            .modifier(TEEditorialRowStyle())
        } else {
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                Text(title)
                    .font(ToonEdgeTypography.body.weight(.semibold))
                Picker(title, selection: selection) {
                    ForEach(values, id: \.self) { value in
                        Text(label(value)).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(accessibilityIdentifier)
            }
            .modifier(TEEditorialRowStyle())
        }
    }

    private var storageItemDescription: String {
        let count = viewModel.storageSummary.cachedItemCount
        return count == 1 ? "1 cached chapter" : "\(count) cached chapters"
    }

    @ViewBuilder
    private var storageDisclosureLabel: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                Label("Downloads", systemImage: "externaldrive")
                    .font(ToonEdgeTypography.body.weight(.semibold))
                Text(storageItemDescription)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                HStack {
                    Text(viewModel.storageSummary.storageDescription)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                    Spacer(minLength: ToonEdgeSpacing.small)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                }
            }
        } else {
            HStack(spacing: ToonEdgeSpacing.medium) {
                Image(systemName: "externaldrive")
                    .frame(width: 28)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                    Text("Downloads")
                        .font(ToonEdgeTypography.body.weight(.semibold))
                    Text(storageItemDescription)
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                }
                Spacer(minLength: ToonEdgeSpacing.small)
                Text(viewModel.storageSummary.storageDescription)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ToonEdgeColor.textSecondary)
            }
        }
    }

    private var displayModeBinding: Binding<ReaderDisplayMode> {
        Binding(get: { viewModel.settings.displayMode }, set: { mode in
            Task { await viewModel.setDisplayMode(mode) }
        })
    }

    private var canvasBinding: Binding<ReaderCanvas> {
        Binding(get: { viewModel.settings.readerCanvas }, set: { canvas in
            Task { await viewModel.setCanvas(canvas) }
        })
    }

    private var pageSpacingBinding: Binding<Bool> {
        Binding(get: { viewModel.settings.isPageSpacingEnabled }, set: { enabled in
            Task { await viewModel.setPageSpacing(enabled) }
        })
    }

    private var brightnessBinding: Binding<Double> {
        Binding(get: { viewModel.settings.brightnessAid }, set: { value in
            Task { await viewModel.setBrightness(value) }
        })
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

private enum SettingsPreference: String, CaseIterable, Identifiable {
    case readerFit, canvas, pageSpacing, brightness

    var id: String { rawValue }
}

private enum SettingsUtility: String, Identifiable {
    case storage, updateCheck, about

    var id: String { rawValue }
}
