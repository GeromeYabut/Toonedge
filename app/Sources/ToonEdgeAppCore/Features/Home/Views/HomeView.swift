import SwiftUI

public struct HomeView: View {
    private let layout = HomeDashboardLayout()
    private let dependencies: AppDependencies
    @Binding private var router: AppRouter
    @State private var snapshot = HomeSnapshot(continueReading: [], recentlyUpdated: [], library: [])
    @State private var hasLoadedSnapshot = false
    @State private var refreshMessage: String?

    public init(dependencies: AppDependencies, router: Binding<AppRouter>) {
        self.dependencies = dependencies
        self._router = router
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ToonEdgeSpacing.xlarge) {
                    ForEach(layout.contentPriority, id: \.self) { section in
                        dashboardSection(section)
                    }
                }
                .padding(ToonEdgeSpacing.large)
            }
            .task {
                await reloadSnapshot()
            }
            .refreshable {
                if layout.refreshPlacement == .pullToRefresh {
                    await refreshUpdates()
                }
            }
            .toonEdgeScreen()
        }
    }

    @ViewBuilder
    private func dashboardSection(_ section: HomeDashboardSection) -> some View {
        switch section {
        case .search:
            searchEntry
            refreshStatus
            if hasLoadedSnapshot && snapshot.isEmpty {
                emptyState
            }
        case .continueReading:
            if !snapshot.continueReading.isEmpty {
                continueReadingSection
            }
        case .recentlyUpdated:
            self.section("Recently Updated", items: snapshot.recentlyUpdated, style: .compact)
        case .libraryPreview:
            self.section("All Library", items: snapshot.library, style: .compact)
        }
    }

    private var searchEntry: some View {
        let layout = HomeSearchEntryLayout()

        return Button {
            router.presentSearch()
        } label: {
            HStack(spacing: ToonEdgeSpacing.small) {
                Image(systemName: "globe")
                    .font(ToonEdgeTypography.body)
                    .foregroundStyle(ToonEdgeColor.textSecondary)

                ViewThatFits(in: .horizontal) {
                    Text(layout.placeholder).fixedSize(horizontal: true, vertical: false)
                    Text("Search or enter URL").fixedSize(horizontal: true, vertical: false)
                    Text("Search / URL")
                }
                .font(ToonEdgeTypography.body)
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .lineLimit(2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, layout.horizontalPadding)
            .frame(minHeight: layout.height)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ToonEdgeSpacing.small)
            .background(ToonEdgeColor.panel, in: RoundedRectangle(cornerRadius: layout.cornerRadius))
        }
        .buttonStyle(TEActionStyle())
        .accessibilityLabel("Search the web or paste a chapter link")
        .accessibilityIdentifier("home.searchEntry")
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
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, ToonEdgeSpacing.medium)
            .padding(.vertical, ToonEdgeSpacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
            Text("Nothing saved yet").font(ToonEdgeTypography.sectionTitle)
            Text("Search or paste a chapter link.")
                .font(ToonEdgeTypography.body)
                .foregroundStyle(ToonEdgeColor.textSecondary)
        }
    }

    @ViewBuilder
    private func section(_ title: String, items: [SeriesSummary], style: HomeSectionStyle) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
                Text(title)
                    .font(ToonEdgeTypography.sectionTitle)

                TEEditorialGroup(items) { item in
                    Button {
                        selectSeries(HomeSeriesSelectionRoute(style: style, seriesID: item.id))
                    } label: {
                        HomeSeriesCard(item: item, style: style)
                    }
                    .buttonStyle(TEActionStyle())
                }
            }
        }
    }

    private var continueReadingSection: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    continueReadingHeading
                    Spacer()
                    continueReadingViewAll
                }
                VStack(alignment: .leading) {
                    continueReadingHeading
                    continueReadingViewAll
                }
            }

            TEEditorialGroup(snapshot.continueReading) { item in
                let style: HomeSectionStyle = item.id == snapshot.continueReading.first?.id ? .featured : .compact
                Button {
                    selectSeries(.continueReading(item.id))
                } label: {
                    HomeSeriesCard(item: item, style: style)
                }
                .buttonStyle(TEActionStyle())
            }
        }
    }

    private var continueReadingHeading: some View {
        Text("Continue Reading")
            .font(ToonEdgeTypography.sectionTitle)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var continueReadingViewAll: some View {
        if snapshot.showsContinueReadingViewAll {
            Button("View All") {
                router.openLibraryRecent()
            }
            .font(ToonEdgeTypography.caption.weight(.semibold))
            .buttonStyle(TEActionStyle())
            .foregroundStyle(ToonEdgeColor.accent)
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

        let result = await updateRefreshService.refreshUpdates()
        await reloadSnapshot()
        refreshMessage = refreshMessage(for: result)
        if let event = InteractionFeedbackOutcomePolicy.updateEvent(for: result, userInitiated: true) {
            dependencies.interactionFeedback.emit(event)
        }
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
    let showsDuplicateSearchCTA = false
    let showsSettingsAccessory = false

    init() {
        self.contentPriority = [.search, .continueReading, .recentlyUpdated, .libraryPreview]
        self.searchPlacement = .compactCommandBar
        self.refreshPlacement = .pullToRefresh
        self.usesCircularTopAccessoryButtons = false
    }
}

enum HomeDashboardSection: Hashable, Sendable {
    case search
    case continueReading
    case recentlyUpdated
    case libraryPreview
}

enum HomeSearchPlacement: Equatable, Sendable {
    case compactCommandBar
}

enum HomeRefreshPlacement: Equatable, Sendable {
    case pullToRefresh
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
    var fixedHeight: CGFloat?
    var coverWidth: CGFloat
    var coverHeight: CGFloat
    var cornerRadius: CGFloat
    var titleLineLimit: Int?
    var progressHeight: CGFloat
    var usesOuterCardContainer: Bool

    init(style: HomeSectionStyle, isAccessibilitySize: Bool = false) {
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
        if isAccessibilitySize {
            self.fixedHeight = nil
            self.titleLineLimit = nil
        }
    }
}

struct HomeRefreshStatusLayout: Equatable, Sendable {
    var message: String
    var usesBannerContainer: Bool

    init(message: String) {
        self.message = message
        self.usesBannerContainer = false
    }
}

private struct HomeSeriesCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: SeriesSummary
    let style: HomeSectionStyle

    var body: some View {
        let layout = HomeSeriesCardLayout(style: style, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibleCard(layout: layout)
            } else if style == .featured {
                featuredCard(layout: layout)
            } else {
                compactCard(layout: layout)
            }
        }
        .frame(height: layout.fixedHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func accessibleCard(layout: HomeSeriesCardLayout) -> some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
            cover(cornerRadius: layout.cornerRadius)
                .frame(width: layout.coverWidth, height: layout.coverHeight)
                .accessibilityHidden(true)
            titleBlock(titleLineLimit: layout.titleLineLimit)
            if style == .featured {
                ProgressView(value: item.progressPercent)
                    .tint(ToonEdgeColor.accent)
                    .accessibilityLabel("Reading progress")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func featuredCard(layout: HomeSeriesCardLayout) -> some View {
        HStack(alignment: .top, spacing: ToonEdgeSpacing.medium) {
            cover(cornerRadius: layout.cornerRadius)
                .frame(width: layout.coverWidth, height: layout.coverHeight)

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                titleBlock(titleLineLimit: layout.titleLineLimit)
                Spacer(minLength: 0)
                ProgressView(value: item.progressPercent)
                    .tint(ToonEdgeColor.accent)
                    .frame(height: layout.progressHeight)
                    .accessibilityLabel("Reading progress")
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

    private func titleBlock(titleLineLimit: Int?) -> some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
            Text(item.title)
                .font(ToonEdgeTypography.body.weight(.semibold))
                .lineLimit(titleLineLimit)
            if item.hasUnreadUpdates {
                Label("New chapters", systemImage: "circle.fill")
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.accent)
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
