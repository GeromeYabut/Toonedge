import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct ReaderView: View {
    @StateObject private var viewModel: ReaderViewModel
    @Binding private var router: AppRouter
    @State private var isSaveStatePickerPresented = false
    @State private var saveState = AddToLibraryStatePickerModel.defaultState(for: .reader)
    @State private var adjacentNavigationTask: Task<Void, Never>?
    @State private var adjacentAnnouncementPolicy = ReaderAdjacentAnnouncementPolicy()
    private let readerService: any ReaderSessionProviding
    private let adjacentLoader: (any AdjacentReaderSessionLoading)?
    private let libraryLifecycleService: (any LibraryLifecycleManaging)?
    private let dismissAction: (() -> Void)?
    private let viewOriginalPageAction: (() -> Void)?
    private let backAction: (() -> Void)?
    private let adjacentSessionDidChange: ((MockReaderSession) -> Void)?
    private let openAdjacentOriginalPageAction: ((URL) -> Void)?

    public init(
        session: MockReaderSession,
        readerService: any ReaderSessionProviding,
        adjacentLoader: (any AdjacentReaderSessionLoading)? = nil,
        progressRepository: any ReaderProgressStoring,
        cacheMetadataManager: (any CacheMetadataManaging)? = nil,
        chapterAssetCache: (any ChapterAssetCaching)? = nil,
        chapterAssetRetainer: (any ChapterAssetRetaining)? = nil,
        recentReadingRecorder: (any RecentReadingRecording)? = nil,
        seriesMetadataService: (any SeriesMetadataFetching)? = nil,
        libraryLifecycleService: (any LibraryLifecycleManaging)? = nil,
        settingsManager: (any SettingsManaging)? = nil,
        interactionFeedback: (any InteractionFeedbackProviding)? = nil,
        dismissAction: (() -> Void)? = nil,
        viewOriginalPageAction: (() -> Void)? = nil,
        backAction: (() -> Void)? = nil,
        adjacentSessionDidChange: ((MockReaderSession) -> Void)? = nil,
        openAdjacentOriginalPageAction: ((URL) -> Void)? = nil,
        router: Binding<AppRouter>
    ) {
        var preparedSession = session
        if let settingsManager {
            preparedSession.settings = settingsManager.currentSettings()
        }
        self._viewModel = StateObject(
            wrappedValue: ReaderViewModel(
                session: preparedSession,
                progressRepository: progressRepository,
                cacheMetadataManager: cacheMetadataManager,
                chapterAssetRetainer: chapterAssetRetainer,
                recentReadingRecorder: recentReadingRecorder,
                libraryLifecycleService: libraryLifecycleService,
                seriesMetadataService: seriesMetadataService,
                settingsManager: settingsManager,
                interactionFeedback: interactionFeedback,
                pagePipelineFactory: { session in
                    ReaderPagePipeline(
                        session: session,
                        assetLoader: DefaultReaderPageAssetLoader(cache: chapterAssetCache)
                    )
                }
            )
        )
        self.readerService = readerService
        self.adjacentLoader = adjacentLoader
        self.libraryLifecycleService = libraryLifecycleService
        self.dismissAction = dismissAction
        self.viewOriginalPageAction = viewOriginalPageAction
        self.backAction = backAction
        self.adjacentSessionDidChange = adjacentSessionDidChange
        self.openAdjacentOriginalPageAction = openAdjacentOriginalPageAction
        self._router = router
    }

    public var body: some View {
        ZStack {
            canvasColor
                .ignoresSafeArea()

            readerStrip
                .environment(\.colorScheme, readerColorScheme)

            if viewModel.isChromeVisible {
                chrome
                    .environment(\.colorScheme, readerColorScheme)
                    .transition(.opacity)
            }

            if let feedback = viewModel.cacheFeedback {
                VStack {
                    TEBanner(
                        title: feedback.isFailure ? "Cache action failed" : "Cache updated",
                        message: feedback.message,
                        systemImage: feedback.isFailure ? "exclamationmark.triangle" : "checkmark.circle"
                    )
                    .padding(ToonEdgeSpacing.large)
                    Spacer()
                }
                .transition(.opacity)
                .onTapGesture {
                    viewModel.clearCacheFeedback()
                }
            }

            if let feedback = viewModel.libraryFeedback {
                VStack {
                    TEBanner(
                        title: feedback.isFailure ? "Save failed" : "Saved",
                        message: feedback.message,
                        systemImage: feedback.isFailure ? "exclamationmark.triangle" : "bookmark.fill"
                    )
                    .padding(ToonEdgeSpacing.large)
                    Spacer()
                }
                .transition(.opacity)
                .onTapGesture {
                    viewModel.clearLibraryFeedback()
                }
            }

            if viewModel.settings.brightnessAid > 0 {
                Color.black
                    .opacity(viewModel.settings.brightnessAid)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader.root")
        .accessibilityValue(readerControlsAccessibilityActionName)
        .accessibilityAction(named: Text(readerControlsAccessibilityActionName)) {
            handleInteraction(.readingSurfaceTap)
        }
        .foregroundStyle(textColor)
        .animation(.easeInOut(duration: 0.16), value: viewModel.isChromeVisible)
        .onAppear {
            viewModel.readerDidAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: readerMemoryPressureNotification)) { _ in
            viewModel.handleReaderMemoryPressure()
        }
        .onChange(of: viewModel.adjacentLoadState) { _, state in
            guard let announcement = adjacentAnnouncementPolicy.announcement(for: state) else {
                return
            }
            #if os(iOS)
            UIAccessibility.post(notification: .announcement, argument: announcement)
            #endif
        }
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            ReaderSettingsView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isSaveStatePickerPresented) {
            AddToLibraryStatePickerView(
                title: viewModel.session.seriesTitle,
                selectedState: $saveState,
                context: .reader,
                confirm: { state in
                    confirmLibrarySave(state: state)
                },
                cancel: {
                    isSaveStatePickerPresented = false
                }
            )
        }
        .onDisappear {
            viewModel.readerDidDisappear()
            adjacentNavigationTask?.cancel()
            adjacentNavigationTask = nil
            viewModel.cancelAdjacentNavigation()
        }
    }

    private var readerStrip: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: viewModel.settings.isPageSpacingEnabled ? ToonEdgeSpacing.small : 0) {
                        ForEach(Array(viewModel.session.imageURLs.enumerated()), id: \.offset) { index, _ in
                            ReaderImagePanel(
                                index: index,
                                displayMode: viewModel.settings.displayMode,
                                availableWidth: geometry.size.width,
                                metadata: viewModel.session.pageMetadata[safe: index],
                                palette: canvasPalette,
                                pipeline: viewModel.pagePipeline,
                                onBecameVisible: { pipelineID, isReady in
                                    Task {
                                        await viewModel.markImageVisible(
                                            index: index,
                                            isReady: isReady,
                                            pipelineID: pipelineID
                                        )
                                    }
                                },
                                onBecameReady: { pipelineID in
                                    Task {
                                        await viewModel.markImageReady(index: index, pipelineID: pipelineID)
                                    }
                                }
                            )
                            .id(index)
                        }
                    }
                    .id(ObjectIdentifier(viewModel.pagePipeline))
                    .padding(.vertical, viewModel.settings.isPageSpacingEnabled ? ToonEdgeSpacing.small : 0)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("reader.readingSurface")
                .contentShape(Rectangle())
                .onTapGesture {
                    handleInteraction(.readingSurfaceTap)
                }
                .task(id: viewModel.session.id) {
                    await viewModel.restoreProgress()
                    proxy.scrollTo(viewModel.progress.currentImageIndex, anchor: .top)
                }
            }
        }
    }

    private var chrome: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Reader controls")
                .accessibilityIdentifier("reader.chrome")
                .accessibilityAddTraits(.isStaticText)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topChrome
                Spacer()
                bottomChrome
            }

            floatingActionRail
                .padding(.trailing, ToonEdgeSpacing.large)
                .padding(.bottom, 132)
        }
    }

    private var topChrome: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            ReaderIconButton(systemImage: "chevron.left", label: "Back", identifier: "reader.back") {
                if let backAction {
                    backAction()
                } else {
                    router.navigateBackFromReader()
                }
            }

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text(viewModel.session.seriesTitle)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .accessibilityIdentifier("reader.series.label")
                Text(viewModel.session.chapterTitle)
                    .font(ToonEdgeTypography.sectionTitle)
                    .lineLimit(1)
                    .accessibilityIdentifier("reader.chapter.context")
            }

            Spacer(minLength: ToonEdgeSpacing.small)

            ReaderIconButton(systemImage: "books.vertical", label: "Open Library", identifier: "reader.library") {
                router.openLibraryRoot()
            }
        }
        .padding(.horizontal, ToonEdgeSpacing.large)
        .padding(.top, ToonEdgeSpacing.large)
        .padding(.bottom, ToonEdgeSpacing.medium)
        .background(.ultraThinMaterial)
        .task {
            await viewModel.refreshSavedState()
        }
    }

    private var floatingActionRail: some View {
        VStack(spacing: ToonEdgeSpacing.small) {
            ReaderIconButton(
                systemImage: "arrow.down.circle",
                label: "Retain Chapter Offline",
                identifier: "reader.retainChapter"
            ) {
                Task {
                    await viewModel.retainCurrentChapter()
                }
            }

            if libraryLifecycleService != nil {
                ReaderIconButton(
                    systemImage: viewModel.isSavedToLibrary ? "bookmark.fill" : "bookmark",
                    label: viewModel.isSavedToLibrary ? "Saved to Library" : "Add to Library",
                    identifier: "reader.saveToLibrary"
                ) {
                    presentLibrarySave()
                }
            }

            ReaderIconButton(
                systemImage: "safari",
                label: "View Original Page",
                identifier: "reader.viewOriginalPage"
            ) {
                viewOriginalPageAction?() ?? router.viewOriginalPage()
            }

            ReaderIconButton(
                systemImage: "gearshape",
                label: "Reader Settings",
                identifier: "reader.settings"
            ) {
                viewModel.showSettings()
            }
        }
        .padding(ToonEdgeSpacing.xsmall)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var bottomChrome: some View {
        VStack(spacing: ToonEdgeSpacing.medium) {
            HStack(spacing: ToonEdgeSpacing.medium) {
                Button {
                    navigate(.previous)
                } label: {
                    if viewModel.adjacentLoadState == .loading(.previous) {
                        ProgressView()
                    } else {
                        Label("Previous", systemImage: "chevron.left")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .frame(minWidth: 96, minHeight: chromeLayout.minimumActionSize, alignment: .leading)
                .accessibilityIdentifier("reader.previousChapter")
                .disabled(!chromeLayout.isEnabled(.previousChapter) || viewModel.isAdjacentLoading)

                Spacer()

                Text(viewModel.currentChapterDisplayLabel)
                    .font(ToonEdgeTypography.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 150)
                    .accessibilityLabel(viewModel.currentChapterAccessibilityLabel)
                    .accessibilityIdentifier("reader.chapter.label")

                Spacer()

                Button {
                    navigate(.next)
                } label: {
                    if viewModel.adjacentLoadState == .loading(.next) {
                        ProgressView()
                    } else {
                        Label("Next", systemImage: "chevron.right")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .frame(minWidth: 96, minHeight: chromeLayout.minimumActionSize, alignment: .trailing)
                .accessibilityIdentifier("reader.nextChapter")
                .disabled(!chromeLayout.isEnabled(.nextChapter) || viewModel.isAdjacentLoading)
            }
            .font(ToonEdgeTypography.caption)
            .buttonStyle(.plain)

            if let presentation = ReaderAdjacentFeedbackPresentation(state: viewModel.adjacentLoadState) {
                adjacentFeedback(presentation)
            }

            HStack(spacing: ToonEdgeSpacing.medium) {
                ProgressView(value: viewModel.progress.fractionComplete)
                    .tint(ToonEdgeColor.accent)
                Text(viewModel.progressDisplay)
                    .font(ToonEdgeTypography.caption)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
                    .accessibilityIdentifier("reader.progress.value")
            }
        }
        .padding(ToonEdgeSpacing.large)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func adjacentFeedback(_ presentation: ReaderAdjacentFeedbackPresentation) -> some View {
        HStack(spacing: ToonEdgeSpacing.small) {
            if presentation.disablesNavigationControls {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: presentation.systemImage)
                    .foregroundStyle(ToonEdgeColor.accent)
                    .accessibilityHidden(true)
            }

            Text(presentation.message)
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(textColor.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: ToonEdgeSpacing.xsmall)

            if presentation.actions.contains(.retry) {
                Button("Retry") {
                    startAdjacentNavigation {
                        await viewModel.retryAdjacentChapter(
                            libraryLifecycleService: libraryLifecycleService,
                            adjacentLoader: adjacentLoader
                        )
                    }
                }
                .frame(
                    minWidth: adjacentRecoveryActionLayout.minimumHitSize(for: .retry),
                    minHeight: adjacentRecoveryActionLayout.minimumHitSize(for: .retry)
                )
                .contentShape(Rectangle())
                .accessibilityIdentifier("reader.adjacent.retry")
            }

            if presentation.actions.contains(.openOriginal),
               let targetURL = viewModel.adjacentFailure?.targetURL {
                Button("Open Original") {
                    if let openAdjacentOriginalPageAction {
                        openAdjacentOriginalPageAction(targetURL)
                    } else {
                        router.openOriginalPage(targetURL)
                    }
                }
                .frame(
                    minWidth: adjacentRecoveryActionLayout.minimumHitSize(for: .openOriginal),
                    minHeight: adjacentRecoveryActionLayout.minimumHitSize(for: .openOriginal)
                )
                .contentShape(Rectangle())
                .accessibilityIdentifier("reader.adjacent.openOriginal")
            }
        }
        .font(ToonEdgeTypography.caption.weight(.semibold))
        .buttonStyle(.plain)
        .padding(.top, ToonEdgeSpacing.xsmall)
        .overlay(alignment: .top) {
            Divider()
                .opacity(0.35)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader.adjacent.feedback")
    }

    private var canvasColor: Color {
        canvasPalette.background.color
    }

    private var textColor: Color {
        canvasPalette.foreground.color
    }

    private var canvasPalette: ReaderCanvasPaletteValues {
        ReaderCanvasPalette.values(for: viewModel.settings.readerCanvas)
    }

    private var readerColorScheme: ColorScheme {
        viewModel.settings.readerCanvas == .paper ? .light : .dark
    }

    private var chromeLayout: ReaderChromeLayout {
        ReaderChromeLayout.actions(
            launchOrigin: viewModel.session.launchOrigin,
            isLibraryAvailable: libraryLifecycleService != nil,
            isSavedToLibrary: viewModel.isSavedToLibrary,
            canNavigatePrevious: viewModel.canNavigatePrevious,
            canNavigateNext: viewModel.canNavigateNext
        )
    }

    private var adjacentRecoveryActionLayout: ReaderAdjacentRecoveryActionLayout {
        ReaderAdjacentRecoveryActionLayout()
    }

    private var readerControlsAccessibilityActionName: String {
        viewModel.isChromeVisible ? "Hide Reader Controls" : "Show Reader Controls"
    }

    private var readerMemoryPressureNotification: Notification.Name {
        #if os(iOS)
        UIApplication.didReceiveMemoryWarningNotification
        #else
        Notification.Name("ToonEdge.readerMemoryPressure")
        #endif
    }

    private func handleInteraction(_ source: ReaderInteractionSource) {
        guard ReaderGesturePolicy().togglesChrome(for: source) else { return }
        viewModel.toggleChrome()
    }

    private func navigate(_ direction: ReaderChapterDirection) {
        startAdjacentNavigation {
            await viewModel.navigateAdjacentChapter(
                direction,
                libraryLifecycleService: libraryLifecycleService,
                adjacentLoader: adjacentLoader
            )
        }
    }

    private func startAdjacentNavigation(
        _ operation: @escaping @MainActor () async -> Bool
    ) {
        adjacentNavigationTask?.cancel()
        adjacentNavigationTask = Task { @MainActor in
            let succeeded = await operation()
            guard succeeded, !Task.isCancelled else { return }
            if let adjacentSessionDidChange {
                adjacentSessionDidChange(viewModel.session)
            } else {
                router.presentReader(viewModel.session)
            }
        }
    }

    private func chapterLabel(from title: String) -> String {
        title
            .split(separator: " ")
            .last
            .map(String.init) ?? title
    }

    private func presentLibrarySave() {
        guard !viewModel.isSavedToLibrary else { return }
        saveState = AddToLibraryStatePickerModel.defaultState(for: .reader)
        isSaveStatePickerPresented = true
    }

    private func confirmLibrarySave(state: LibraryCollectionState) {
        isSaveStatePickerPresented = false
        Task {
            await viewModel.saveCurrentSessionToLibrary(libraryState: state)
        }
    }
}

enum ReaderInteractionSource: Equatable {
    case readingSurfaceTap
    case scroll
    case toolbarAction
}

struct ReaderGesturePolicy {
    func togglesChrome(for source: ReaderInteractionSource) -> Bool {
        source == .readingSurfaceTap
    }
}

enum ReaderChromeAction: Equatable {
    case back
    case download
    case save
    case saved
    case library
    case viewOriginalPage
    case settings
    case previousChapter
    case nextChapter
}

struct ReaderChromeLayout: Equatable {
    var launchOrigin: ReaderLaunchOrigin
    var top: [ReaderChromeAction]
    var floating: [ReaderChromeAction]
    var bottom: [ReaderChromeAction]
    var enabledActions: [ReaderChromeAction]
    var showsChapterContext: Bool
    var showsProgress: Bool
    var minimumActionSize: CGFloat

    var actions: [ReaderChromeAction] {
        top + floating + bottom
    }

    static func actions(
        launchOrigin: ReaderLaunchOrigin,
        isLibraryAvailable: Bool,
        isSavedToLibrary: Bool,
        canNavigatePrevious: Bool,
        canNavigateNext: Bool
    ) -> ReaderChromeLayout {
        var floating: [ReaderChromeAction] = [.download]
        if isLibraryAvailable {
            floating.append(isSavedToLibrary ? .saved : .save)
        }
        floating.append(contentsOf: [.viewOriginalPage, .settings])

        var enabledActions = [ReaderChromeAction.back, .library] + floating
        if canNavigatePrevious {
            enabledActions.append(.previousChapter)
        }
        if canNavigateNext {
            enabledActions.append(.nextChapter)
        }

        return ReaderChromeLayout(
            launchOrigin: launchOrigin,
            top: [.back, .library],
            floating: floating,
            bottom: [.previousChapter, .nextChapter],
            enabledActions: enabledActions,
            showsChapterContext: true,
            showsProgress: true,
            minimumActionSize: 44
        )
    }

    func isEnabled(_ action: ReaderChromeAction) -> Bool {
        enabledActions.contains(action)
    }

    func identifier(for action: ReaderChromeAction) -> String {
        switch action {
        case .back: "reader.back"
        case .download: "reader.retainChapter"
        case .save, .saved: "reader.saveToLibrary"
        case .library: "reader.library"
        case .viewOriginalPage: "reader.viewOriginalPage"
        case .settings: "reader.settings"
        case .previousChapter: "reader.previousChapter"
        case .nextChapter: "reader.nextChapter"
        }
    }
}

enum ReaderAdjacentRecoveryAction: Equatable {
    case retry
    case openOriginal
}

struct ReaderAdjacentRecoveryActionLayout: Equatable {
    func minimumHitSize(for action: ReaderAdjacentRecoveryAction) -> CGFloat {
        switch action {
        case .retry, .openOriginal:
            44
        }
    }
}

struct ReaderAdjacentFeedbackPresentation: Equatable {
    let message: String
    let systemImage: String
    let actions: [ReaderAdjacentRecoveryAction]
    let disablesNavigationControls: Bool
    let isCompact = true
    let keepsCurrentSessionVisible = true

    init?(state: AdjacentChapterLoadState) {
        switch state {
        case .idle:
            return nil
        case .loading(let direction):
            message = direction == .previous ? "Loading previous chapter…" : "Loading next chapter…"
            systemImage = "arrow.trianglehead.2.clockwise"
            actions = []
            disablesNavigationControls = true
        case .failed(let failure):
            switch failure.reason {
            case .timeout:
                message = "Chapter timed out."
            case .challengeOrRateLimit:
                message = "Reader access is temporarily limited."
            case .unavailable:
                message = "Chapter unavailable in Reader."
            case .lowConfidence:
                message = "Chapter could not be verified."
            case .nonViableImages:
                message = "No usable chapter images found."
            }
            systemImage = "exclamationmark.circle"
            actions = failure.targetURL == nil ? [.retry] : [.retry, .openOriginal]
            disablesNavigationControls = false
        }
    }
}

struct ReaderAdjacentAnnouncementPolicy {
    private var lastState: AdjacentChapterLoadState?

    mutating func announcement(for state: AdjacentChapterLoadState) -> String? {
        guard state != lastState else { return nil }
        lastState = state
        guard let presentation = ReaderAdjacentFeedbackPresentation(state: state) else {
            return nil
        }
        return presentation.message.replacingOccurrences(of: "…", with: ".")
    }
}

private struct ReaderImagePanel: View {
    let index: Int
    let displayMode: ReaderDisplayMode
    let availableWidth: CGFloat
    let metadata: ReaderPageMetadata?
    let palette: ReaderCanvasPaletteValues
    @ObservedObject var pipeline: ReaderPagePipeline
    let onBecameVisible: (ObjectIdentifier, Bool) -> Void
    let onBecameReady: (ObjectIdentifier) -> Void
    @State private var isVisible = false

    var body: some View {
        Group {
            switch state.status {
            case .idle, .queued, .loading:
                placeholder
                    .overlay {
                        ProgressView()
                            .tint(palette.foreground.color)
                    }
            case .ready:
                if let decoded = state.image {
                    Image(decorative: decoded.cgImage, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: imageWidth)
                        .accessibilityLabel("Reader image \(index + 1)")
                } else {
                    failurePlaceholder
                }
            case .failed:
                failurePlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            isVisible = true
            pipeline.updateVisibleIndex(index)
            onBecameVisible(ObjectIdentifier(pipeline), state.status == .ready)
        }
        .onDisappear {
            isVisible = false
        }
        .onChange(of: state.status) { _, status in
            guard isVisible, status == .ready else { return }
            onBecameReady(ObjectIdentifier(pipeline))
        }
    }

    private var failurePlaceholder: some View {
        placeholder
            .overlay {
                VStack(spacing: ToonEdgeSpacing.small) {
                    Image(systemName: "photo")
                        .foregroundStyle(palette.foreground.color)
                    Text("Page \(index + 1) unavailable. Connect to the internet and retry.")
                        .font(ToonEdgeTypography.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.foreground.color)
                        .accessibilityIdentifier("reader.page.failed.\(index + 1)")
                    Button("Retry") {
                        pipeline.retry(index: index)
                    }
                    .font(ToonEdgeTypography.caption)
                }
            }
    }

    private var state: ReaderPageState {
        pipeline.states[index] ?? ReaderPageState(status: .idle, image: nil, failure: nil)
    }

    private var imageWidth: CGFloat {
        switch displayMode {
        case .fitWidth:
            availableWidth
        case .fitScreen:
            availableWidth * 0.92
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(palette.background.color)
            .frame(
                width: imageWidth,
                height: ReaderPageLayout.placeholderHeight(
                    availableWidth: availableWidth,
                    displayMode: displayMode,
                    metadata: metadata
                )
            )
            .overlay {
                Text("Page \(index + 1)")
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(palette.foreground.color)
            }
    }
}

public enum ReaderPageLayout {
    public static func placeholderHeight(
        availableWidth: CGFloat,
        displayMode: ReaderDisplayMode,
        metadata: ReaderPageMetadata?
    ) -> CGFloat {
        guard
            let metadata,
            metadata.pixelWidth > 0,
            metadata.pixelHeight > 0
        else {
            return 430
        }

        let renderedWidth: CGFloat
        switch displayMode {
        case .fitWidth:
            renderedWidth = availableWidth
        case .fitScreen:
            renderedWidth = availableWidth * 0.92
        }

        return renderedWidth * CGFloat(metadata.pixelHeight / metadata.pixelWidth)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct ReaderIconButton: View {
    let systemImage: String
    let label: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
