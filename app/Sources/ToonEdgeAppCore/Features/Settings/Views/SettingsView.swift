import SwiftUI

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public private(set) var settings: ReaderSettings
    @Published public private(set) var storageSummary: DownloadSummary
    @Published public private(set) var isCheckingForUpdates = false
    @Published public private(set) var updateMessage: String?

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
        guard let updateRefreshService else {
            updateMessage = "Update checking is unavailable."
            return
        }
        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }
        let result = await updateRefreshService.refreshUpdates()
        if result.failedCount > 0 {
            updateMessage = "Checked \(result.checkedCount) series; \(result.failedCount) could not be refreshed."
        } else if result.updatedCount > 0 {
            updateMessage = "Found updates for \(result.updatedCount) series."
        } else {
            updateMessage = "No new chapters found."
        }
    }
}

public struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
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
                        VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
                            Text("Reader Fit").font(ToonEdgeTypography.body.weight(.semibold))
                            Picker("Reader Fit", selection: displayModeBinding) {
                                ForEach(ReaderDisplayMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("settings.readerFit")

                            Text("Canvas").font(ToonEdgeTypography.body.weight(.semibold))
                            Picker("Canvas", selection: canvasBinding) {
                                Text("Charcoal").tag(ReaderCanvas.charcoal)
                                Text("Black").tag(ReaderCanvas.black)
                                Text("Paper").tag(ReaderCanvas.paper)
                            }
                            .pickerStyle(.segmented)

                            Toggle("Page Spacing", isOn: pageSpacingBinding)
                                .font(ToonEdgeTypography.body)

                            VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                                Text("Brightness Aid").font(ToonEdgeTypography.body.weight(.semibold))
                                Slider(value: brightnessBinding, in: 0...0.75)
                                    .tint(ToonEdgeColor.accent)
                            }
                        }
                    }

                    settingsSection("Storage Management") {
                        VStack(spacing: ToonEdgeSpacing.medium) {
                            TEListRow(
                                title: "\(viewModel.storageSummary.cachedItemCount) cached chapters",
                                subtitle: viewModel.storageSummary.storageDescription,
                                systemImage: "externaldrive"
                            )
                            Button(action: onShowDownloads) {
                                Label("Manage Downloads", systemImage: "arrow.down.circle")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("settings.manageDownloads")
                        }
                    }

                    settingsSection("New Chapters") {
                        VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
                            Button {
                                Task { await viewModel.refreshUpdates() }
                            } label: {
                                Label(
                                    viewModel.isCheckingForUpdates ? "Checking…" : "Check for New Chapters",
                                    systemImage: "arrow.clockwise"
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isCheckingForUpdates)
                            .accessibilityIdentifier("settings.checkUpdates")

                            if let message = viewModel.updateMessage {
                                Text(message)
                                    .font(ToonEdgeTypography.caption)
                                    .foregroundStyle(ToonEdgeColor.textSecondary)
                                    .accessibilityIdentifier("settings.updateResult")
                            }
                        }
                    }

                    settingsSection("About ToonEdge") {
                        VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                            Text("ToonEdge \(appVersion)")
                                .font(ToonEdgeTypography.body.weight(.semibold))
                            Text("ToonEdge is a local-first reading browser. Content remains on its source website, and protected viewers stay in the browser.")
                                .font(ToonEdgeTypography.caption)
                                .foregroundStyle(ToonEdgeColor.textSecondary)
                            Text("Support and legal information will be provided with the App Store release.")
                                .font(ToonEdgeTypography.caption)
                                .foregroundStyle(ToonEdgeColor.textSecondary)
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
            TECard(content: content)
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
