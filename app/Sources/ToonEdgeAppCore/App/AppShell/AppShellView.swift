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

            DownloadsView(dependencies: dependencies)
                .tabItem {
                    Label(AppTab.downloads.title, systemImage: "arrow.down.circle")
                        .accessibilityIdentifier("tab.downloads")
                }
                .tag(AppTab.downloads)

            SettingsView(dependencies: dependencies) {
                router.selectedTab = .downloads
            }
                .tabItem {
                    Label(AppTab.settings.title, systemImage: "gearshape")
                        .accessibilityIdentifier("tab.settings")
                }
                .tag(AppTab.settings)
        }
        .tint(ToonEdgeColor.accent)
        .sheet(
            isPresented: Binding(
                get: { router.activeSheet == .search },
                set: { isPresented in
                    if !isPresented {
                        router.dismissSheet()
                    }
                }
            )
        ) {
            SearchOverlayView(
                suggestionsProvider: dependencies.searchSuggestionProvider,
                searchHistoryRecorder: dependencies.searchHistoryRecorder,
                interactionFeedback: dependencies.interactionFeedback,
                router: $router
            )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .toonEdgeFullScreenCover(
            isPresented: Binding(
                get: { router.presentedBrowser != nil },
                set: { isPresented in
                    if !isPresented {
                        router.dismissBrowser()
                    }
                }
            )
        ) {
            BrowserView(
                startPoint: router.presentedBrowser ?? .searchQuery(""),
                readerLaunchOriginOverride: router.presentedBrowserReaderLaunchOrigin,
                dependencies: dependencies,
                router: $router
            )
        }
        .toonEdgeFullScreenCover(
            isPresented: Binding(
                get: { router.presentedReader != nil },
                set: { isPresented in
                    if !isPresented {
                        router.dismissReader()
                    }
                }
            )
        ) {
            ReaderView(
                session: router.presentedReader ?? .sample,
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
                router: $router
            )
            .id(router.presentedReader?.id)
        }
    }
}
