import SwiftUI

public struct AppShellView: View {
    private let dependencies: AppDependencies
    @State private var router: AppRouter

    public init(dependencies: AppDependencies = .mock(), initialRouter: AppRouter = AppRouter()) {
        self.dependencies = dependencies
        self._router = State(initialValue: initialRouter)
    }

    public var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeView(dependencies: dependencies, router: $router)
                .tabItem {
                    Label(AppTab.home.title, systemImage: "house")
                        .accessibilityIdentifier("tab.home")
                }
                .tag(AppTab.home)

            LibraryView(dependencies: dependencies, router: $router)
                .tabItem {
                    Label(AppTab.library.title, systemImage: "books.vertical")
                        .accessibilityIdentifier("tab.library")
                }
                .tag(AppTab.library)

            DownloadsView(dependencies: dependencies, onSearch: { router.presentSearch() })
                .tabItem {
                    Label(AppTab.downloads.title, systemImage: "arrow.down.circle")
                        .accessibilityIdentifier("tab.downloads")
                }
                .tag(AppTab.downloads)

            SettingsView(dependencies: dependencies, onSearch: { router.presentSearch() }) {
                router.selectedTab = .downloads
            }
                .tabItem {
                    Label(AppTab.settings.title, systemImage: "gearshape")
                        .accessibilityIdentifier("tab.settings")
                }
                .tag(AppTab.settings)
        }
        .tint(ToonEdgeColor.accent)
        .preferredColorScheme(ToonEdgeAppearancePolicy.default.forcedColorScheme)
        .universalSearch(isPresented: rootSearchPresentation, dependencies: dependencies) {
            $0.apply(to: &router)
        }
        .toonEdgeFullScreenCover(
            isPresented: Binding(
                get: { router.presentedBrowser != nil || router.presentedReader != nil },
                set: { isPresented in
                    if !isPresented {
                        router.dismissReader()
                        router.dismissBrowser()
                    }
                }
            )
        ) {
            modalContent
                .preferredColorScheme(ToonEdgeAppearancePolicy.default.forcedColorScheme)
        }
    }

    private var rootSearchPresentation: Binding<Bool> {
        Binding(
            get: { router.activeSheet == .search &&
                router.presentedReader == nil && router.presentedBrowser == nil },
            set: { if !$0 { router.dismissSheet() } }
        )
    }

    @ViewBuilder
    private var modalContent: some View {
        if let session = router.presentedReader {
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
                searchAction: { router.presentSearch() },
                router: $router
            )
            .id(session.id)
            .universalSearch(
                isPresented: Binding(
                    get: { router.activeSheet == .search },
                    set: { if !$0 { router.dismissSheet() } }
                ),
                dependencies: dependencies
            ) { $0.apply(to: &router) }
        } else if let startPoint = router.presentedBrowser {
            BrowserView(
                startPoint: startPoint,
                readerLaunchOriginOverride: router.presentedBrowserReaderLaunchOrigin,
                dependencies: dependencies,
                router: $router
            )
        }
    }
}
