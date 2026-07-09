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
    private let readerService: any ReaderSessionProviding
    private let adjacentLoader: (any AdjacentReaderSessionLoading)?
    private let libraryLifecycleService: (any LibraryLifecycleManaging)?
    private let dismissAction: (() -> Void)?
    private let viewOriginalPageAction: (() -> Void)?
    private let backAction: (() -> Void)?
    private let navigateAdjacentChapterAction: ((MockChapter) -> Void)?

    public init(
        session: MockReaderSession,
        readerService: any ReaderSessionProviding,
        adjacentLoader: (any AdjacentReaderSessionLoading)? = nil,
        progressRepository: any ReaderProgressStoring,
        cacheMetadataManager: (any CacheMetadataManaging)? = nil,
        recentReadingRecorder: (any RecentReadingRecording)? = nil,
        seriesMetadataService: (any SeriesMetadataFetching)? = nil,
        libraryLifecycleService: (any LibraryLifecycleManaging)? = nil,
        dismissAction: (() -> Void)? = nil,
        viewOriginalPageAction: (() -> Void)? = nil,
        backAction: (() -> Void)? = nil,
        navigateAdjacentChapterAction: ((MockChapter) -> Void)? = nil,
        router: Binding<AppRouter>
    ) {
        self._viewModel = StateObject(
            wrappedValue: ReaderViewModel(
                session: session,
                progressRepository: progressRepository,
                cacheMetadataManager: cacheMetadataManager,
                recentReadingRecorder: recentReadingRecorder,
                libraryLifecycleService: libraryLifecycleService,
                seriesMetadataService: seriesMetadataService
            )
        )
        self.readerService = readerService
        self.adjacentLoader = adjacentLoader
        self.libraryLifecycleService = libraryLifecycleService
        self.dismissAction = dismissAction
        self.viewOriginalPageAction = viewOriginalPageAction
        self.backAction = backAction
        self.navigateAdjacentChapterAction = navigateAdjacentChapterAction
        self._router = router
    }

    public var body: some View {
        ZStack {
            canvasColor
                .ignoresSafeArea()

            readerStrip

            if viewModel.isChromeVisible {
                chrome
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
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.toggleChrome()
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
            VStack(spacing: 0) {
                topChrome
                Spacer()
                bottomChrome
            }

            floatingActionRail
                .padding(.trailing, ToonEdgeSpacing.large)
                .padding(.bottom, 132)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.74),
                    Color.black.opacity(0.22),
                    Color.clear,
                    Color.black.opacity(0.30),
                    Color.black.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
        .onTapGesture {
            viewModel.toggleChrome()
        }
    }

    private var topChrome: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            ReaderIconButton(systemImage: "chevron.left", label: "Back") {
                if let backAction {
                    backAction()
                } else {
                    router.navigateBackFromReader()
                }
            }

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text(viewModel.session.seriesTitle)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .lineLimit(1)
                Text(viewModel.session.chapterTitle)
                    .font(ToonEdgeTypography.sectionTitle)
                    .lineLimit(1)
            }

            Spacer(minLength: ToonEdgeSpacing.small)

            ReaderIconButton(systemImage: "house", label: "Open Home") {
                router.openHomeRoot()
            }
        }
        .padding(.horizontal, ToonEdgeSpacing.large)
        .padding(.top, ToonEdgeSpacing.large)
        .padding(.bottom, ToonEdgeSpacing.medium)
        .task {
            await viewModel.refreshSavedState()
        }
    }

    private var floatingActionRail: some View {
        VStack(spacing: ToonEdgeSpacing.small) {
            ReaderIconButton(systemImage: "arrow.down.circle", label: "Retain Chapter Offline") {
                Task {
                    await viewModel.retainCurrentChapter()
                }
            }

            if libraryLifecycleService != nil {
                ReaderIconButton(
                    systemImage: viewModel.isSavedToLibrary ? "bookmark.fill" : "bookmark",
                    label: viewModel.isSavedToLibrary ? "Saved to Library" : "Add to Library"
                ) {
                    presentLibrarySave()
                }
            }

            ReaderIconButton(systemImage: "safari", label: "View Original Page") {
                viewOriginalPageAction?() ?? router.viewOriginalPage()
            }

            ReaderIconButton(systemImage: "gearshape", label: "Reader Settings") {
                viewModel.showSettings()
            }
        }
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
                .frame(minWidth: 96, alignment: .leading)
                .disabled(!viewModel.canNavigatePrevious || viewModel.adjacentLoadState != .idle)

                Spacer()

                Text(viewModel.currentChapterDisplayLabel)
                    .font(ToonEdgeTypography.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 150)
                    .accessibilityLabel(viewModel.currentChapterAccessibilityLabel)

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
                .frame(minWidth: 96, alignment: .trailing)
                .disabled(!viewModel.canNavigateNext || viewModel.adjacentLoadState != .idle)
            }
            .font(ToonEdgeTypography.caption)
            .buttonStyle(.plain)

            if let message = viewModel.adjacentFailureMessage {
                Text(message)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: ToonEdgeSpacing.medium) {
                ProgressView(value: viewModel.progress.fractionComplete)
                    .tint(ToonEdgeColor.accent)
                Text(viewModel.progressDisplay)
                    .font(ToonEdgeTypography.caption)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(ToonEdgeSpacing.large)
        .background(.ultraThinMaterial)
    }

    private var canvasColor: Color {
        switch viewModel.settings.readerCanvas {
        case .charcoal:
            ToonEdgeColor.background
        case .black:
            .black
        case .paper:
            Color(red: 0.89, green: 0.86, blue: 0.78)
        }
    }

    private var textColor: Color {
        viewModel.settings.readerCanvas == .paper ? Color(red: 0.10, green: 0.09, blue: 0.08) : ToonEdgeColor.textPrimary
    }

    private func navigate(_ direction: ReaderChapterDirection) {
        if let navigateAdjacentChapterAction {
            let chapter = direction == .previous ? viewModel.session.previousChapter : viewModel.session.nextChapter
            guard let chapter else { return }
            navigateAdjacentChapterAction(chapter)
            return
        }

        Task {
            await viewModel.navigateAdjacentChapter(
                direction,
                libraryLifecycleService: libraryLifecycleService,
                adjacentLoader: adjacentLoader
            )
            router.presentReader(viewModel.session)
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

enum ReaderChromeAction: Equatable {
    case back
    case home
    case download
    case save
    case saved
    case library
    case viewOriginalPage
    case settings
}

struct ReaderChromeLayout: Equatable {
    var top: [ReaderChromeAction]
    var floating: [ReaderChromeAction]
    var bottom: [ReaderChromeAction]

    static func actions(isLibraryAvailable: Bool, isSavedToLibrary: Bool) -> ReaderChromeLayout {
        var floating: [ReaderChromeAction] = [.download]
        if isLibraryAvailable {
            floating.append(isSavedToLibrary ? .saved : .save)
        }
        floating.append(contentsOf: [.viewOriginalPage, .settings])

        return ReaderChromeLayout(
            top: [.back, .home],
            floating: floating,
            bottom: []
        )
    }
}

private struct ReaderImagePanel: View {
    let imageURL: URL
    let index: Int
    let displayMode: ReaderDisplayMode
    let availableWidth: CGFloat
    let metadata: ReaderPageMetadata?
    let onImageLoaded: () -> Void
    @StateObject private var loader: ReaderPageImageLoader

    init(
        imageURL: URL,
        index: Int,
        displayMode: ReaderDisplayMode,
        availableWidth: CGFloat,
        metadata: ReaderPageMetadata?,
        onImageLoaded: @escaping () -> Void
    ) {
        self.imageURL = imageURL
        self.index = index
        self.displayMode = displayMode
        self.availableWidth = availableWidth
        self.metadata = metadata
        self.onImageLoaded = onImageLoaded
        self._loader = StateObject(wrappedValue: ReaderPageImageLoader(imageURL: imageURL))
    }

    var body: some View {
        Group {
            switch loader.state {
            case .idle, .loading:
                placeholder
                    .overlay {
                        ProgressView()
                            .tint(ToonEdgeColor.textSecondary)
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
                        .foregroundStyle(ToonEdgeColor.textSecondary)
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
            .fill(ToonEdgeColor.panel)
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
                    .foregroundStyle(ToonEdgeColor.textSecondary)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.34), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
