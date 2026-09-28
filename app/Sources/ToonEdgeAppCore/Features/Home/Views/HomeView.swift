import SwiftUI

public struct HomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let dependencies: AppDependencies
    @Binding private var router: AppRouter
    @State private var snapshot = HomeSnapshot(continueReading: [], recentlyUpdated: [], library: [])
    @State private var hasLoadedSnapshot = false
    @State private var isRefreshingUpdates = false
    @State private var refreshMessage: String?

    public init(dependencies: AppDependencies, router: Binding<AppRouter>) {
        self.dependencies = dependencies
        self._router = router
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ToonEdgeSpacing.xlarge) {
                    topBar
                    refreshStatus

                    if hasLoadedSnapshot && snapshot.isEmpty {
                        emptyState
                    } else {
                        continueReadingSection
                        section("Recently Updated", items: snapshot.recentlyUpdated, style: .compact)
                        section("All Library", items: snapshot.library, style: .compact)
                    }
                }
                .padding(ToonEdgeSpacing.large)
            }
            .task {
                await reloadSnapshot()
            }
            .refreshable {
                await refreshUpdates()
            }
            .toonEdgeScreen()
        }
    }

    private var topBar: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            searchEntry
            settingsButton
            refreshButton
        }
    }

    private var searchEntry: some View {
        let layout = HomeSearchEntryLayout()

        return Button {
            router.presentSearch()
        } label: {
            HStack(spacing: ToonEdgeSpacing.small) {
                Image(systemName: "globe")
                    .font(dynamicTypeSize.isAccessibilitySize ? .system(size: 22, weight: .semibold) : ToonEdgeTypography.body.weight(.semibold))
                    .foregroundStyle(ToonEdgeColor.textSecondary)

                ViewThatFits(in: .horizontal) {
                    Text(layout.placeholder).fixedSize(horizontal: true, vertical: false)
                    Text("Search or enter URL").fixedSize(horizontal: true, vertical: false)
                    Text("Search / URL")
                }
                .font(dynamicTypeSize.isAccessibilitySize ? .system(size: 22) : ToonEdgeTypography.body)
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .lineLimit(2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, layout.horizontalPadding)
            .frame(minHeight: layout.height)
            .frame(maxWidth: .infinity)
            .background(ToonEdgeColor.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: layout.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .stroke(ToonEdgeColor.border.opacity(0.55))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search the web or paste a chapter link")
        .accessibilityIdentifier("home.searchEntry")
    }

    private var settingsButton: some View {
        let layout = HomeTopAccessoryLayout()

        return Button {
            router.selectedTab = .settings
        } label: {
            Image(systemName: "gearshape")
                .font(ToonEdgeTypography.body.weight(.semibold))
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .frame(width: layout.size, height: layout.size)
                .background(ToonEdgeColor.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: layout.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: layout.cornerRadius).stroke(ToonEdgeColor.border.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }

    private var refreshButton: some View {
        let layout = HomeTopAccessoryLayout()

        return Button {
            Task {
                await refreshUpdates()
            }
        } label: {
            Image(systemName: isRefreshingUpdates ? "hourglass" : "arrow.clockwise")
                .font(ToonEdgeTypography.body.weight(.semibold))
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .frame(width: layout.size, height: layout.size)
                .background(ToonEdgeColor.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: layout.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: layout.cornerRadius).stroke(ToonEdgeColor.border.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .disabled(isRefreshingUpdates || dependencies.updateRefreshService == nil)
        .accessibilityLabel("Check for new chapters")
    }

    @ViewBuilder
    private var refreshStatus: some View {
        if let refreshMessage {
            let layout = HomeRefreshStatusLayout(message: refreshMessage)

            HStack(spacing: ToonEdgeSpacing.small) {
                Image(systemName: "arrow.clockwise")
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.accent)

                Text(layout.message)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, ToonEdgeSpacing.medium)
            .padding(.vertical, ToonEdgeSpacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ToonEdgeColor.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: layout.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: layout.cornerRadius).stroke(ToonEdgeColor.border.opacity(0.45)))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
            TEBanner(
                title: "No saved reading yet",
                message: "Start with search or paste a chapter link. Your reading progress will appear here later.",
                systemImage: "book.closed"
            )

            TEButton("Start a web reading session", systemImage: "magnifyingglass") {
                router.presentSearch()
            }
        }
    }

    private func section(_ title: String, items: [SeriesSummary], style: HomeSectionStyle) -> some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
            Text(title)
                .font(ToonEdgeTypography.sectionTitle)

            if items.isEmpty {
                TEBanner(title: "Nothing here yet", message: "This section will fill as mock state changes.", systemImage: "tray")
            } else {
                VStack(spacing: ToonEdgeSpacing.small) {
                    ForEach(items) { item in
                        Button {
                            selectSeries(HomeSeriesSelectionRoute(style: style, seriesID: item.id))
                        } label: {
                            HomeSeriesCard(item: item, style: style)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var continueReadingSection: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
            HStack {
                Text("Continue Reading")
                    .font(ToonEdgeTypography.sectionTitle)
                Spacer()
                if snapshot.showsContinueReadingViewAll {
                    Button("View All") {
                        router.openLibraryRecent()
                    }
                    .font(ToonEdgeTypography.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(ToonEdgeColor.accent)
                }
            }

            if snapshot.continueReading.isEmpty {
                TEBanner(title: "Nothing here yet", message: "This section will fill as mock state changes.", systemImage: "tray")
            } else {
                let featured = snapshot.continueReading.first
                let remaining = Array(snapshot.continueReading.dropFirst())

                VStack(spacing: ToonEdgeSpacing.small) {
                    if let featured {
                        Button {
                            selectSeries(HomeSeriesSelectionRoute(style: .featured, seriesID: featured.id))
                        } label: {
                            HomeSeriesCard(item: featured, style: .featured)
                        }
                        .buttonStyle(.plain)
                    }

                    if !remaining.isEmpty {
                        VStack(spacing: ToonEdgeSpacing.xsmall) {
                            ForEach(remaining) { item in
                                Button {
                                    selectSeries(.continueReading(item.id))
                                } label: {
                                    HomeSeriesCard(item: item, style: .compact)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func selectSeries(_ route: HomeSeriesSelectionRoute) {
        switch route {
        case .continueReading(let seriesID):
            openContinueReading(seriesID: seriesID)
        case .libraryDetail(let seriesID):
            router.openLibraryDetail(seriesID: seriesID)
        }
    }

    private func openContinueReading(seriesID: UUID) {
        Task {
            let target = await dependencies.libraryLifecycleService?.continueReadingTarget(for: seriesID)
            if let target,
               let session = await dependencies.libraryLifecycleService?.readerSession(forChapterID: target.chapterID) {
                var librarySession = session
                librarySession.launchOrigin = .homeContinueReading
                router.presentReader(librarySession)
                return
            }

            HomeContinueReadingNavigation.presentBrowserFallback(for: target, router: &router)
        }
    }

    private func reloadSnapshot() async {
        snapshot = await dependencies.libraryService.homeSnapshot()
        hasLoadedSnapshot = true
    }

    private func refreshUpdates() async {
        guard let updateRefreshService = dependencies.updateRefreshService else {
            return
        }

        isRefreshingUpdates = true
        let result = await updateRefreshService.refreshUpdates()
        await reloadSnapshot()
        isRefreshingUpdates = false
        refreshMessage = refreshMessage(for: result)
    }

    private func refreshMessage(for result: LibraryUpdateRefreshResult) -> String {
        if result.failedCount > 0 {
            return "Checked \(result.checkedCount), found \(result.updatedCount) updates, \(result.failedCount) failed."
        }

        return "Checked \(result.checkedCount), found \(result.updatedCount) updates."
    }

    private func chapterTitle(from subtitle: String) -> String {
        if subtitle.hasPrefix("Continue Chapter ") {
            return subtitle.replacingOccurrences(of: "Continue ", with: "")
        }

        if subtitle.hasPrefix("Continue ") {
            return "Chapter \(subtitle.replacingOccurrences(of: "Continue ", with: ""))"
        }

        return "Chapter"
    }
}

enum HomeSeriesSelectionRoute: Equatable {
    case continueReading(UUID)
    case libraryDetail(UUID)

    init(style: HomeSectionStyle, seriesID: UUID) {
        self = style == .featured ? .continueReading(seriesID) : .libraryDetail(seriesID)
    }
}

enum HomeContinueReadingNavigation {
    static func browserStartPoint(for target: ContinueReadingTarget?) -> BrowserStartPoint? {
        target.map { .url($0.sourceURL.absoluteString) }
    }

    static func presentBrowserFallback(for target: ContinueReadingTarget?, router: inout AppRouter) {
        guard let startPoint = browserStartPoint(for: target) else { return }
        router.presentBrowser(startPoint, readerLaunchOrigin: .homeContinueReading)
    }
}

struct HomeDashboardLayout: Equatable, Sendable {
    var contentPriority: [HomeDashboardSection]
    var searchPlacement: HomeSearchPlacement
    var refreshPlacement: HomeRefreshPlacement
    var usesCircularTopAccessoryButtons: Bool

    init() {
        self.contentPriority = [.search, .continueReading, .recentlyUpdated, .libraryPreview]
        self.searchPlacement = .compactCommandBar
        self.refreshPlacement = .inlineStatus
        self.usesCircularTopAccessoryButtons = false
    }
}

enum HomeDashboardSection: Equatable, Sendable {
    case search
    case continueReading
    case recentlyUpdated
    case libraryPreview
}

enum HomeSearchPlacement: Equatable, Sendable {
    case compactCommandBar
}

enum HomeRefreshPlacement: Equatable, Sendable {
    case inlineStatus
}

struct HomeSearchEntryLayout: Equatable, Sendable {
    var placeholder: String
    var height: CGFloat
    var cornerRadius: CGFloat
    var usesCapsuleShape: Bool
    var horizontalPadding: CGFloat

    init() {
        self.placeholder = "Search the web or paste a chapter link"
        self.height = 44
        self.cornerRadius = 10
        self.usesCapsuleShape = false
        self.horizontalPadding = ToonEdgeSpacing.medium
    }
}

struct HomeSeriesCardLayout: Equatable, Sendable {
    var fixedHeight: CGFloat
    var coverWidth: CGFloat
    var coverHeight: CGFloat
    var cornerRadius: CGFloat
    var titleLineLimit: Int
    var progressHeight: CGFloat
    var usesOuterCardContainer: Bool

    init(style: HomeSectionStyle) {
        switch style {
        case .featured:
            self.fixedHeight = 156
            self.coverWidth = 92
            self.coverHeight = 132
            self.cornerRadius = 6
            self.titleLineLimit = 2
            self.progressHeight = 4
            self.usesOuterCardContainer = false
        case .compact:
            self.fixedHeight = 86
            self.coverWidth = 48
            self.coverHeight = 64
            self.cornerRadius = 5
            self.titleLineLimit = 1
            self.progressHeight = 0
            self.usesOuterCardContainer = false
        }
    }
}

struct HomeTopAccessoryLayout: Equatable, Sendable {
    var size: CGFloat
    var cornerRadius: CGFloat
    var usesCircleShape: Bool

    init() {
        self.size = 40
        self.cornerRadius = 10
        self.usesCircleShape = false
    }
}

struct HomeRefreshStatusLayout: Equatable, Sendable {
    var message: String
    var cornerRadius: CGFloat
    var usesBannerContainer: Bool

    init(message: String) {
        self.message = message
        self.cornerRadius = 10
        self.usesBannerContainer = false
    }
}

private struct HomeSeriesCard: View {
    let item: SeriesSummary
    let style: HomeSectionStyle

    var body: some View {
        let layout = HomeSeriesCardLayout(style: style)

        Group {
            if style == .featured {
                featuredCard(layout: layout)
            } else {
                compactCard(layout: layout)
            }
        }
        .frame(height: layout.fixedHeight)
        .contentShape(Rectangle())
    }

    private func featuredCard(layout: HomeSeriesCardLayout) -> some View {
        HStack(alignment: .top, spacing: ToonEdgeSpacing.medium) {
            cover(cornerRadius: layout.cornerRadius)
                .frame(width: layout.coverWidth, height: layout.coverHeight)

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                titleBlock(titleLineLimit: layout.titleLineLimit)
                Spacer(minLength: 0)
                ProgressView(value: item.progressPercent)
                    .tint(item.hasUnreadUpdates ? ToonEdgeColor.success : ToonEdgeColor.accent)
                    .frame(height: layout.progressHeight)
            }
            .frame(minHeight: layout.coverHeight)

            Spacer(minLength: 0)

            Image(systemName: "play.fill")
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .padding(.top, ToonEdgeSpacing.small)
        }
        .padding(.vertical, ToonEdgeSpacing.small)
    }

    private func compactCard(layout: HomeSeriesCardLayout) -> some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            cover(cornerRadius: layout.cornerRadius)
                .frame(width: layout.coverWidth, height: layout.coverHeight)

            titleBlock(titleLineLimit: layout.titleLineLimit)

            Spacer(minLength: ToonEdgeSpacing.small)

            Image(systemName: "chevron.right")
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.textSecondary)
        }
        .padding(.vertical, ToonEdgeSpacing.xsmall)
    }

    private func titleBlock(titleLineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
            HStack(spacing: ToonEdgeSpacing.small) {
                Text(item.title)
                    .font(ToonEdgeTypography.body.weight(.semibold))
                    .lineLimit(titleLineLimit)
                if item.hasUnreadUpdates {
                    TEChip("New", isActive: true)
                }
            }

            Text(item.subtitle)
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.textSecondary)
        }
    }

    private func cover(cornerRadius: CGFloat) -> some View {
        CachedCoverArtwork(url: item.coverImageURL) {
            coverPlaceholder(cornerRadius: cornerRadius)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(ToonEdgeColor.border.opacity(0.55))
        )
    }

    private func coverPlaceholder(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(item.hasUnreadUpdates ? ToonEdgeColor.success.opacity(0.22) : ToonEdgeColor.accentSoft.opacity(0.82))
            .overlay {
                Image(systemName: item.hasUnreadUpdates ? "sparkle" : "book.pages")
                    .foregroundStyle(item.hasUnreadUpdates ? ToonEdgeColor.success : ToonEdgeColor.accent)
            }
    }
}

enum HomeSectionStyle {
    case featured
    case compact
}
