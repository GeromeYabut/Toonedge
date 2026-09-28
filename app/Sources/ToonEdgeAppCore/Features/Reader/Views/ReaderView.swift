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
    private let readerService: any ReaderSessionProviding
    private let adjacentLoader: (any AdjacentReaderSessionLoading)?
    private let libraryLifecycleService: (any LibraryLifecycleManaging)?
    private let dismissAction: (() -> Void)?
    private let viewOriginalPageAction: (() -> Void)?
    private let backAction: (() -> Void)?
    private let adjacentSessionDidChange: ((MockReaderSession) -> Void)?
    private let openAdjacentOriginalPageAction: ((URL) -> Void)?
    private let chapterAssetCache: (any ChapterAssetCaching)?

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
                settingsManager: settingsManager
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
        self.chapterAssetCache = chapterAssetCache
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
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            ReaderSettingsView(viewModel: viewModel)
                .presentationDetents([.medium])
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
                        ForEach(Array(viewModel.session.imageURLs.enumerated()), id: \.offset) { index, imageURL in
                            ReaderImagePanel(
                                imageURL: imageURL,
                                index: index,
                                displayMode: viewModel.settings.displayMode,
                                availableWidth: geometry.size.width,
                                metadata: viewModel.session.pageMetadata[safe: index],
                                sourceURL: viewModel.session.sourceURL,
                                assetCache: chapterAssetCache,
                                palette: canvasPalette,
                                requestContext: viewModel.session.imageRequestContext,
                                onImageLoaded: {
                                    Task {
                                        await viewModel.markImageLoaded(index: index)
                                    }
                                }
                            )
                            .id(index)
                            .onAppear {
                                Task {
                                    await viewModel.markImageVisible(index: index)
                                }
                            }
                        }
                    }
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

            if let failure = viewModel.adjacentFailure {
                VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                    Text(failure.message)
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(textColor)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: ToonEdgeSpacing.medium) {
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

                        if let targetURL = failure.targetURL {
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
                    .buttonStyle(.borderless)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private func emitSaveHaptic() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
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
            emitSaveHaptic()
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

private struct ReaderImagePanel: View {
    let imageURL: URL
    let index: Int
    let displayMode: ReaderDisplayMode
    let availableWidth: CGFloat
    let metadata: ReaderPageMetadata?
    let sourceURL: URL
    let assetCache: (any ChapterAssetCaching)?
    let palette: ReaderCanvasPaletteValues
    let onImageLoaded: () -> Void
    @StateObject private var loader: ReaderPageImageLoader

    init(
        imageURL: URL,
        index: Int,
        displayMode: ReaderDisplayMode,
        availableWidth: CGFloat,
        metadata: ReaderPageMetadata?,
        sourceURL: URL,
        assetCache: (any ChapterAssetCaching)?,
        palette: ReaderCanvasPaletteValues,
        requestContext: ReaderImageRequestContext?,
        onImageLoaded: @escaping () -> Void
    ) {
        self.imageURL = imageURL
        self.index = index
        self.displayMode = displayMode
        self.availableWidth = availableWidth
        self.metadata = metadata
        self.sourceURL = sourceURL
        self.assetCache = assetCache
        self.palette = palette
        self.onImageLoaded = onImageLoaded
        self._loader = StateObject(wrappedValue: ReaderPageImageLoader(
            imageURL: imageURL,
            sourceURL: sourceURL,
            assetCache: assetCache,
            requestContext: requestContext
        ))
    }

    var body: some View {
        Group {
            switch loader.state {
            case .idle, .loading:
                placeholder
                    .overlay {
                        ProgressView()
                            .tint(palette.foreground.color)
                    }
            case .loaded(let data):
                if let image = image(from: data) {
                    image
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
        .task(id: imageURL) {
            await loader.load()
        }
        .onChange(of: loader.state) { _, state in
            guard case .loaded(let data) = state, image(from: data) != nil else {
                return
            }

            onImageLoaded()
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
                        Task {
                            await loader.retry()
                        }
                    }
                    .font(ToonEdgeTypography.caption)
                }
            }
    }

    private func image(from data: Data) -> Image? {
        #if canImport(UIKit)
        guard let platformImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: platformImage)
        #elseif canImport(AppKit)
        guard let platformImage = NSImage(data: data) else {
            return nil
        }
        return Image(nsImage: platformImage)
        #else
        return nil
        #endif
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
