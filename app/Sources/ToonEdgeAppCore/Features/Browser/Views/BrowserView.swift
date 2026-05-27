import SwiftUI

public struct BrowserView: View {
    private let dependencies: AppDependencies
    @Binding private var router: AppRouter
    @StateObject private var viewModel: BrowserViewModel

    public init(
        startPoint: BrowserStartPoint,
        dependencies: AppDependencies,
        router: Binding<AppRouter>
    ) {
        self.dependencies = dependencies
        self._router = router
        self._viewModel = StateObject(wrappedValue: BrowserViewModel(startPoint: startPoint))
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
                    recentReadingRecorder: dependencies.recentReadingRecorder,
                    seriesMetadataService: dependencies.seriesMetadataService,
                    libraryLifecycleService: dependencies.libraryLifecycleService,
                    dismissAction: {
                        viewModel.dismissBrowserOwnedReader()
                    },
                    viewOriginalPageAction: {
                        viewModel.dismissBrowserOwnedReader()
                    },
                    backAction: {
                        viewModel.dismissBrowserOwnedReader()
                        viewModel.load(session.seriesURL)
                    },
                    navigateAdjacentChapterAction: { chapter in
                        viewModel.load(chapter.sourceURL)
                    },
                    router: $router
                )
                .id(session.id)
                .transition(.opacity)
                .zIndex(1)
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
        }
    }

    private var browserChrome: some View {
        VStack(spacing: 0) {
            topBar

            ZStack(alignment: .top) {
                BrowserWebView(viewModel: viewModel, detector: dependencies.chapterDetector)
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
                }
            }

            bottomControls
        }
    }

    private var topBar: some View {
        HStack(spacing: ToonEdgeSpacing.small) {
            Button {
                router.dismissBrowser()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ToonEdgeColor.textPrimary)

            HStack(spacing: ToonEdgeSpacing.small) {
                Image(systemName: viewModel.initialRequestIconName)
                    .foregroundStyle(ToonEdgeColor.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.addressDisplay.isEmpty ? "Search or enter URL" : viewModel.addressDisplay)
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.textPrimary)
                        .lineLimit(1)
                    Text(viewModel.subtitleDisplay)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
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

            Button {
                viewModel.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ToonEdgeColor.textPrimary)

            if viewModel.detectionResult?.readerSession != nil, dependencies.libraryLifecycleService != nil {
                Button {
                    addDetectedSessionToLibrary()
                } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ToonEdgeColor.textPrimary)
                .accessibilityLabel("Add detected series to library")
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
                    .frame(width: 44, height: 44)
            }
            .disabled(!viewModel.canGoBack)

            Button {
                viewModel.goForward()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .disabled(!viewModel.canGoForward)

            Spacer()

            Text(viewModel.isLoading ? "Loading" : "Browser")
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.textSecondary)

            Spacer()

            Button {
                viewModel.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(ToonEdgeColor.textPrimary)
        .padding(.horizontal, ToonEdgeSpacing.large)
        .padding(.vertical, ToonEdgeSpacing.small)
        .background(ToonEdgeColor.elevated)
    }

    private var cleanModeBanner: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ToonEdgeColor.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Read in Clean Mode")
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textPrimary)
                Text("ToonEdge found a likely chapter page.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                viewModel.enterCleanModeManually()
            } label: {
                Image(systemName: "book")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ToonEdgeColor.textPrimary)
        }
        .padding(ToonEdgeSpacing.medium)
        .background(ToonEdgeColor.elevated, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: ToonEdgeRadius.medium)
                .stroke(ToonEdgeColor.border)
        )
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

    private func addDetectedSessionToLibrary() {
        guard let session = viewModel.detectionResult?.readerSession,
              let lifecycleService = dependencies.libraryLifecycleService else {
            return
        }

        Task {
            try? await lifecycleService.addToLibrary(
                LibrarySeriesInput(
                    title: session.seriesTitle,
                    canonicalURL: session.sourceURL.deletingLastPathComponent(),
                    sourceDomain: session.sourceURL.host() ?? viewModel.addressDisplay,
                    coverImageURL: nil,
                    status: "Reading",
                    synopsis: "Saved from Browser.",
                    latestKnownChapterLabel: chapterLabel(from: session.chapterTitle),
                    libraryState: .planned,
                    chapters: [
                        LibraryChapterInput(
                            title: session.chapterTitle,
                            chapterLabel: chapterLabel(from: session.chapterTitle),
                            chapterNumber: Double(chapterLabel(from: session.chapterTitle)),
                            sourceURL: session.sourceURL,
                            imageURLs: session.imageURLs,
                            publishedAt: nil
                        )
                    ]
                ),
                context: .browser
            )
        }
    }

    private func chapterLabel(from title: String) -> String {
        title
            .split(separator: " ")
            .last
            .map(String.init) ?? title
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
