import SwiftUI

public struct BrowserChromeLayout: Equatable, Sendable {
    public enum ReloadPlacement: Equatable, Sendable {
        case bottomToolbar
    }

    public let reloadPlacement: ReloadPlacement = .bottomToolbar
    public let showsTopReload = false
    public let showsDecorativeBrowserStatus = false
    public let minimumActionSize: CGFloat = 44
    public let cleanModeActionIdentifier = "browser.cleanModeAction"
    public let closeActionIdentifier = "browser.close"
    public let reloadActionIdentifier = "browser.reload"
    public let backActionIdentifier = "browser.back"
    public let forwardActionIdentifier = "browser.forward"

    public init() {}
}

public struct BrowserView: View {
    private let dependencies: AppDependencies
    @Binding private var router: AppRouter
    @StateObject private var viewModel: BrowserViewModel
    @StateObject private var librarySaveOperation: BrowserLibrarySaveOperation
    private let chromeLayout = BrowserChromeLayout()
    @State private var pendingLibrarySaveSession: MockReaderSession?
    @State private var librarySaveState = AddToLibraryStatePickerModel.defaultState(for: .browser)

    public init(
        startPoint: BrowserStartPoint,
        readerLaunchOriginOverride: ReaderLaunchOrigin? = nil,
        dependencies: AppDependencies,
        router: Binding<AppRouter>
    ) {
        self.dependencies = dependencies
        self._router = router
        self._viewModel = StateObject(
            wrappedValue: BrowserViewModel(
                startPoint: startPoint,
                readerLaunchOriginOverride: readerLaunchOriginOverride
            )
        )
        self._librarySaveOperation = StateObject(
            wrappedValue: BrowserLibrarySaveOperation(
                interactionFeedback: dependencies.interactionFeedback
            )
        )
    }

    public var body: some View {
        ZStack {
            browserChrome

            if let session = viewModel.browserOwnedReaderSession {
                ReaderView(
                    session: session,
                    readerService: dependencies.readerService,
                    adjacentLoader: dependencies.adjacentReaderSessionLoader,
                    progressRepository: dependencies.readerProgressRepository,
                    cacheMetadataManager: dependencies.cacheMetadataService,
                    chapterAssetCache: dependencies.chapterAssetCache,
                    chapterAssetRetainer: dependencies.chapterAssetRetainer,
                    recentReadingRecorder: dependencies.recentReadingRecorder,
                    seriesMetadataService: dependencies.seriesMetadataService,
                    libraryLifecycleService: dependencies.libraryLifecycleService,
                    settingsManager: dependencies.settingsService,
                    interactionFeedback: dependencies.interactionFeedback,
                    dismissAction: {
                        viewModel.dismissBrowserOwnedReader()
                    },
                    viewOriginalPageAction: {
                        viewModel.dismissBrowserOwnedReader()
                    },
                    backAction: {
                        switch BrowserOwnedReaderBackRoute(session: session).apply(to: &router) {
                        case .handledByRouter:
                            viewModel.dismissBrowserOwnedReader()
                        case .showBrowserSeriesPage(let seriesURL):
                            viewModel.dismissBrowserOwnedReader()
                            viewModel.load(seriesURL)
                        case .dismissReaderOnly:
                            viewModel.dismissBrowserOwnedReader()
                        }
                    },
                    adjacentSessionDidChange: { session in
                        viewModel.replaceBrowserOwnedReaderSession(session)
                    },
                    openAdjacentOriginalPageAction: { url in
                        viewModel.dismissBrowserOwnedReader()
                        viewModel.load(url)
                    },
                    router: $router
                )
                .id(session.id)
                .transition(.opacity)
                .zIndex(1)
            }

            if let failureMessage = librarySaveOperation.failureMessage {
                VStack {
                    TEBanner(
                        title: "Save failed",
                        message: failureMessage,
                        systemImage: "exclamationmark.triangle"
                    )
                    .padding(ToonEdgeSpacing.large)
                    Spacer()
                }
                .accessibilityIdentifier("browser.librarySave.failure")
                .zIndex(2)
            } else if let successMessage = librarySaveOperation.successMessage {
                VStack {
                    TEBanner(
                        title: successMessage,
                        message: "This series is now available in Library.",
                        systemImage: "checkmark.circle"
                    )
                    .padding(ToonEdgeSpacing.large)
                    Spacer()
                }
                .accessibilityIdentifier("browser.librarySave.success")
                .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.browserOwnedReaderSession?.id)
        .toonEdgeScreen()
        .task {
            await dependencies.browserService.prepare(viewModel.startPoint)
        }
        .onChange(of: viewModel.pendingReaderSession) { _, session in
            guard let session else { return }
            viewModel.presentPendingReaderInsideBrowser(session)
            if viewModel.browserOwnedReaderSession != nil {
                router.clearPresentedBrowserReaderLaunchOrigin()
            }
        }
        .onChange(of: viewModel.detectionResult?.readerSession?.id) { _, sessionID in
            librarySaveOperation.reset(for: sessionID)
        }
        .sheet(item: $pendingLibrarySaveSession) { session in
            AddToLibraryStatePickerView(
                title: session.seriesTitle,
                selectedState: $librarySaveState,
                context: .browser,
                confirm: { state in
                    confirmDetectedSessionLibrarySave(session, state: state)
                },
                cancel: {
                    pendingLibrarySaveSession = nil
                }
            )
        }
    }

    private var browserChrome: some View {
        VStack(spacing: 0) {
            topBar

            ZStack(alignment: .top) {
                BrowserWebView(
                    viewModel: viewModel,
                    detector: dependencies.chapterDetector,
                    presentationFixture: dependencies.browserPresentationFixture
                )
                    .background(Color.white)

                if viewModel.initialRequest == nil {
                    invalidRequestView
                }

                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(ToonEdgeColor.accent)
                        .frame(maxWidth: .infinity)
                }

                if viewModel.showsCleanModeCTA {
                    cleanModeBanner
                        .padding(.horizontal, ToonEdgeSpacing.medium)
                        .padding(.top, ToonEdgeSpacing.medium)
                } else if let message = viewModel.readerUnavailableMessage {
                    readerUnavailableFeedback(message)
                        .padding(.horizontal, ToonEdgeSpacing.medium)
                        .padding(.top, ToonEdgeSpacing.medium)
                }
            }

            bottomControls
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("browser.root")
    }

    private var topBar: some View {
        HStack(spacing: ToonEdgeSpacing.small) {
            Button {
                router.dismissBrowser()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: chromeLayout.minimumActionSize, height: chromeLayout.minimumActionSize)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ToonEdgeColor.textPrimary)
            .accessibilityIdentifier(chromeLayout.closeActionIdentifier)

            HStack(spacing: ToonEdgeSpacing.small) {
                Image(systemName: viewModel.initialRequestIconName)
                    .foregroundStyle(ToonEdgeColor.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.addressDisplay.isEmpty ? "Search or enter URL" : viewModel.addressDisplay)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ToonEdgeColor.textPrimary)
                        .lineLimit(1)
                    Text(viewModel.subtitleDisplay)
                        .font(.caption)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, ToonEdgeSpacing.medium)
            .padding(.vertical, ToonEdgeSpacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ToonEdgeColor.panel, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: ToonEdgeRadius.medium)
                    .stroke(ToonEdgeColor.border)
            )

            if viewModel.detectionResult?.readerSession != nil, dependencies.libraryLifecycleService != nil {
                Button {
                    presentDetectedSessionLibrarySave()
                } label: {
                    Image(systemName: librarySaveOperation.isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: chromeLayout.minimumActionSize, height: chromeLayout.minimumActionSize)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ToonEdgeColor.textPrimary)
                .disabled(librarySaveOperation.isSaving || librarySaveOperation.isSaved)
                .accessibilityLabel(
                    librarySaveOperation.isSaved
                        ? "Detected series saved to library"
                        : "Add detected series to library"
                )
            }
        }
        .padding(.horizontal, ToonEdgeSpacing.medium)
        .padding(.vertical, ToonEdgeSpacing.small)
        .background(ToonEdgeColor.elevated)
    }

    private var bottomControls: some View {
        HStack(spacing: ToonEdgeSpacing.xlarge) {
            Button {
                viewModel.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: chromeLayout.minimumActionSize, height: chromeLayout.minimumActionSize)
            }
            .disabled(!viewModel.canGoBack)
            .accessibilityIdentifier(chromeLayout.backActionIdentifier)

            Button {
                viewModel.goForward()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: chromeLayout.minimumActionSize, height: chromeLayout.minimumActionSize)
            }
            .disabled(!viewModel.canGoForward)
            .accessibilityIdentifier(chromeLayout.forwardActionIdentifier)

            Spacer()

            if chromeLayout.reloadPlacement == .bottomToolbar {
                Button {
                    viewModel.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: chromeLayout.minimumActionSize, height: chromeLayout.minimumActionSize)
                }
                .accessibilityIdentifier(chromeLayout.reloadActionIdentifier)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(ToonEdgeColor.textPrimary)
        .padding(.horizontal, ToonEdgeSpacing.large)
        .padding(.vertical, ToonEdgeSpacing.small)
        .background(ToonEdgeColor.elevated)
    }

    private var cleanModeBanner: some View {
        Button {
            viewModel.enterCleanModeManually()
        } label: {
            HStack(spacing: ToonEdgeSpacing.medium) {
                Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ToonEdgeColor.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Clean Mode available")
                        .font(ToonEdgeTypography.body.weight(.semibold))
                        .foregroundStyle(ToonEdgeColor.textPrimary)
                    Text("A likely chapter page is ready to read.")
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: ToonEdgeSpacing.xsmall) {
                    Text("Read")
                        .font(ToonEdgeTypography.body.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(ToonEdgeColor.accent)
            }
        }
        .buttonStyle(.plain)
        .padding(ToonEdgeSpacing.medium)
        .background(ToonEdgeColor.elevated, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
        .contentShape(RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
        .frame(minHeight: chromeLayout.minimumActionSize)
        .accessibilityIdentifier(chromeLayout.cleanModeActionIdentifier)
    }

    private func readerUnavailableFeedback(_ message: String) -> some View {
        HStack(alignment: .top, spacing: ToonEdgeSpacing.small) {
            Image(systemName: "globe")
                .foregroundStyle(ToonEdgeColor.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Continue on the original page")
                    .font(ToonEdgeTypography.caption.weight(.semibold))
                    .foregroundStyle(ToonEdgeColor.textPrimary)
                Text(message)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(ToonEdgeSpacing.medium)
        .background(ToonEdgeColor.elevated, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
        .accessibilityElement(children: .combine)
    }

    private var invalidRequestView: some View {
        VStack(spacing: ToonEdgeSpacing.medium) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(ToonEdgeColor.accent)
            Text("Unable to open this address")
                .font(ToonEdgeTypography.sectionTitle)
            Text(viewModel.startPoint.displayText)
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(ToonEdgeSpacing.xlarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ToonEdgeColor.background)
    }

    private func presentDetectedSessionLibrarySave() {
        guard let session = viewModel.detectionResult?.readerSession else {
            return
        }

        librarySaveState = AddToLibraryStatePickerModel.defaultState(for: .browser)
        pendingLibrarySaveSession = session
    }

    private func confirmDetectedSessionLibrarySave(_ session: MockReaderSession, state: LibraryCollectionState) {
        pendingLibrarySaveSession = nil
        guard let lifecycleService = dependencies.libraryLifecycleService else {
            return
        }

        Task {
            let input = DetectedSessionLibraryInputBuilder.input(
                for: session,
                addressDisplay: viewModel.addressDisplay,
                libraryState: state
            )
            await librarySaveOperation.perform(sessionID: session.id) {
                try await lifecycleService.addToLibrary(input, context: .browser)
            }
        }
    }
}

@MainActor
final class BrowserLibrarySaveOperation: ObservableObject {
    @Published private(set) var failureMessage: String?
    @Published private(set) var successMessage: String?
    @Published private(set) var isSaving = false
    private let interactionFeedback: any InteractionFeedbackProviding
    private var currentSessionID: UUID?
    private var activeOperationID: UUID?

    init(interactionFeedback: any InteractionFeedbackProviding) {
        self.interactionFeedback = interactionFeedback
    }

    var isSaved: Bool { successMessage != nil }

    func reset(for sessionID: UUID? = nil) {
        currentSessionID = sessionID
        activeOperationID = nil
        isSaving = false
        failureMessage = nil
        successMessage = nil
    }

    @discardableResult
    func perform(
        sessionID: UUID? = nil,
        _ operation: () async throws -> Void
    ) async -> Bool {
        if let sessionID {
            if currentSessionID == nil {
                currentSessionID = sessionID
            }
            guard currentSessionID == sessionID else { return false }
        }
        guard !isSaving, !isSaved else { return false }
        let operationID = UUID()
        activeOperationID = operationID
        isSaving = true
        do {
            try await operation()
            guard activeOperationID == operationID, currentSessionID == sessionID else {
                return false
            }
            activeOperationID = nil
            isSaving = false
            failureMessage = nil
            successMessage = "Saved to Library"
            interactionFeedback.emit(.operationSucceeded)
            return true
        } catch {
            guard activeOperationID == operationID, currentSessionID == sessionID else {
                return false
            }
            activeOperationID = nil
            isSaving = false
            failureMessage = "Could not save this series."
            return false
        }
    }
}

public enum BrowserOwnedReaderBackResolution: Equatable, Sendable {
    case handledByRouter
    case showBrowserSeriesPage(URL)
    case dismissReaderOnly
}

public struct BrowserOwnedReaderBackRoute: Equatable, Sendable {
    public var session: MockReaderSession

    public init(session: MockReaderSession) {
        self.session = session
    }

    @discardableResult
    public func apply(to router: inout AppRouter) -> BrowserOwnedReaderBackResolution {
        switch session.launchOrigin {
        case .library(let seriesID):
            router.openLibraryDetail(seriesID: seriesID)
            return .handledByRouter
        case .homeContinueReading:
            router.openHomeRoot()
            return .handledByRouter
        case .browser:
            return .showBrowserSeriesPage(session.seriesURL)
        case .direct:
            return .dismissReaderOnly
        }
    }
}

enum DetectedSessionLibraryInputBuilder {
    static func input(
        for session: MockReaderSession,
        addressDisplay: String,
        libraryState: LibraryCollectionState = AddToLibraryStatePickerModel.defaultState(for: .browser)
    ) -> LibrarySeriesInput {
        let chapterLabel = ChapterNumericLabelExtractor.label(
            chapterNumber: nil,
            chapterLabel: session.chapterTitle,
            title: session.sourceURL.absoluteString
        ) ?? session.chapterTitle

        return LibrarySeriesInput(
            id: session.seriesID,
            title: session.seriesTitle,
            canonicalURL: CanonicalSeriesURLResolver.seriesURL(for: session.sourceURL),
            sourceDomain: session.sourceURL.host() ?? addressDisplay,
            coverImageURL: session.coverImageURL,
            status: "Reading",
            synopsis: "Saved from Browser.",
            latestKnownChapterLabel: chapterLabel,
            libraryState: libraryState,
            chapters: [
                LibraryChapterInput(
                    title: session.chapterTitle,
                    chapterLabel: chapterLabel,
                    chapterNumber: Double(chapterLabel),
                    sourceURL: session.sourceURL,
                    previousChapterURL: session.previousChapter?.sourceURL,
                    nextChapterURL: session.nextChapter?.sourceURL,
                    imageURLs: session.imageURLs,
                    publishedAt: nil
                )
            ]
        )
    }
}

private extension BrowserViewModel {
    var initialRequestIconName: String {
        switch startPoint {
        case .url:
            "lock"
        case .searchQuery:
            "magnifyingglass"
        }
    }
}
