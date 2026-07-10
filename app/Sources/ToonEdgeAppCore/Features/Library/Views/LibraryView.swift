import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct LibraryView: View {
    private let dependencies: AppDependencies
    @Binding private var router: AppRouter
    @State private var snapshot = LibrarySnapshot(series: [])
    @State private var selectedSegment: LibrarySegment = .recent
    @State private var selectedViewMode: LibraryViewMode
    @State private var hasLoadedSnapshot = false
    @State private var isRefreshingUpdates = false
    @State private var refreshFeedback: LibraryRefreshFeedback?
    @State private var navigationPath: [UUID] = []
    private let libraryViewPreferences: LibraryViewPreferences

    public init(dependencies: AppDependencies, router: Binding<AppRouter>) {
        self.dependencies = dependencies
        self._router = router
        let preferences = LibraryViewPreferences()
        self.libraryViewPreferences = preferences
        self._selectedViewMode = State(initialValue: preferences.selectedViewMode)
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
                    LibraryFilterRow(selection: $selectedSegment)
                    summaryPill
                    LibraryViewModeControl(selection: $selectedViewMode)
                    content
                }
                .padding(ToonEdgeSpacing.large)
            }
            .overlay(alignment: .bottomTrailing) {
                floatingRefreshFeedback
            }
            .animation(.easeInOut(duration: 0.2), value: refreshFeedback)
            .navigationTitle("Library")
            .task {
                await reloadSnapshot()
                if let segment = router.consumePendingLibrarySegment() {
                    selectedSegment = segment
                }
                if let seriesID = router.consumePendingLibrarySeriesID() {
                    navigationPath = [seriesID]
                }
            }
            .onChange(of: router.pendingLibrarySegment) { _, pendingSegment in
                guard let pendingSegment else { return }
                selectedSegment = pendingSegment
                _ = router.consumePendingLibrarySegment()
            }
            .onChange(of: router.pendingLibrarySeriesID) { _, pendingSeriesID in
                guard let pendingSeriesID else { return }
                navigationPath = [pendingSeriesID]
                _ = router.consumePendingLibrarySeriesID()
            }
            .refreshable {
                await refreshUpdates()
            }
            .onChange(of: selectedViewMode) { _, mode in
                libraryViewPreferences.selectedViewMode = mode
            }
            .navigationDestination(for: UUID.self) { seriesID in
                SeriesDetailView(seriesID: seriesID, dependencies: dependencies, router: $router)
            }
            .toonEdgeScreen()
        }
    }

    @ViewBuilder
    private var floatingRefreshFeedback: some View {
        if let refreshFeedback {
            LibraryRefreshFeedbackView(layout: refreshFeedback.layout) {
                dismissRefreshFeedback()
            }
            .padding(.horizontal, ToonEdgeSpacing.large)
            .padding(.bottom, ToonEdgeSpacing.large)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            ))
            .zIndex(1)
        }
    }

    private var summaryPill: some View {
        let visible = snapshot.series(for: selectedSegment)
        let layout = LibrarySummaryPillLayout(
            segment: selectedSegment,
            visibleSeries: visible,
            hasUpdateRefreshService: dependencies.updateRefreshService != nil,
            isRefreshing: isRefreshingUpdates
        )

        return LibrarySummaryPill(layout: layout) {
            Task {
                await refreshUpdates()
            }
        }
    }

    private func reloadSnapshot() async {
        snapshot = await dependencies.libraryService.librarySnapshot()
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
        showRefreshFeedback(message: refreshMessage(for: result))
    }

    private func refreshMessage(for result: LibraryUpdateRefreshResult) -> String {
        if result.failedCount > 0 {
            return "\(result.checkedCount) checked, \(result.updatedCount) \(pluralize("update", count: result.updatedCount)), \(result.failedCount) failed"
        }

        return "\(result.checkedCount) checked, \(result.updatedCount) \(pluralize("update", count: result.updatedCount))"
    }

    private func pluralize(_ singular: String, count: Int) -> String {
        count == 1 ? singular : "\(singular)s"
    }

    @ViewBuilder
    private var content: some View {
        let visible = snapshot.series(for: selectedSegment)
        let emptyLayout = LibraryEmptyStateLayout(hasLoadedSnapshot: hasLoadedSnapshot, visibleSeries: visible)

        if emptyLayout.isVisible {
            LibraryEmptyStateView(layout: emptyLayout)
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: gridMinimumWidth), spacing: ToonEdgeSpacing.medium)],
                spacing: ToonEdgeSpacing.medium
            ) {
                ForEach(visible) { series in
                    NavigationLink(value: series.id) {
                        switch selectedViewMode {
                        case .comfortable:
                            SeriesCard(series: series, layout: .comfortable)
                        case .compact:
                            SeriesCard(series: series, layout: .compact)
                        case .list:
                            SeriesListRow(series: series)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var gridMinimumWidth: CGFloat {
        switch selectedViewMode {
        case .comfortable:
            return 150
        case .compact:
            return 118
        case .list:
            return 320
        }
    }

    private func showRefreshFeedback(message: String) {
        let feedback = LibraryRefreshFeedback(message: message)
        refreshFeedback = feedback

        Task { [feedbackID = feedback.id] in
            try? await Task.sleep(for: .seconds(LibraryRefreshFeedbackLayout.autoDismissDelay))
            if refreshFeedback?.id == feedbackID {
                refreshFeedback = nil
            }
        }
    }

    private func dismissRefreshFeedback() {
        refreshFeedback = nil
    }
}

struct LibraryHeaderLayout: Equatable, Sendable {
    var navigationTitle: String
    var contentTitle: String?
    var toolbarRefreshIsAvailable: Bool

    init(hasUpdateRefreshService: Bool) {
        self.navigationTitle = "Library"
        self.contentTitle = nil
        self.toolbarRefreshIsAvailable = false
    }
}

struct LibrarySummaryPillLayout: Equatable, Sendable {
    var title: String
    var message: String
    var refreshButtonIsVisible: Bool
    var refreshSystemImage: String
    var refreshAccessibilityLabel: String

    init(
        segment: LibrarySegment,
        visibleSeries: [LibrarySeriesSummary],
        hasUpdateRefreshService: Bool,
        isRefreshing: Bool
    ) {
        let updateCount = visibleSeries.filter(\.hasUnreadUpdates).count

        self.title = "\(segment.title) Library"
        self.message = updateCount > 0
            ? "\(updateCount) with new chapters"
            : "\(visibleSeries.count) saved \(visibleSeries.count == 1 ? "title" : "titles")"
        self.refreshButtonIsVisible = hasUpdateRefreshService
        self.refreshSystemImage = isRefreshing ? "hourglass" : "arrow.clockwise"
        self.refreshAccessibilityLabel = "Check for new chapters"
    }
}

struct LibraryRefreshFeedbackLayout: Equatable, Sendable {
    static let autoDismissDelay = 5

    var title: String
    var message: String
    var presentationStyle: LibraryRefreshFeedbackPresentationStyle
    var overlayAlignment: LibraryRefreshFeedbackOverlayAlignment
    var maximumWidth: CGFloat
    var contentSize: LibraryRefreshFeedbackContentSize
    var accentColorRole: LibraryRefreshFeedbackAccentColorRole
    var reservesContentSpace: Bool
    var dismissAccessibilityLabel: String
    var autoDismissDelay: Int

    init(message: String) {
        self.title = "Updated"
        self.message = message
        self.presentationStyle = .floatingOverlay
        self.overlayAlignment = .bottomTrailing
        self.maximumWidth = 280
        self.contentSize = .compact
        self.accentColorRole = .purple
        self.reservesContentSpace = false
        self.dismissAccessibilityLabel = "Dismiss update refresh"
        self.autoDismissDelay = Self.autoDismissDelay
    }
}

enum LibraryRefreshFeedbackPresentationStyle: Equatable, Sendable {
    case floatingOverlay
}

enum LibraryRefreshFeedbackOverlayAlignment: Equatable, Sendable {
    case bottomTrailing
}

enum LibraryRefreshFeedbackContentSize: Equatable, Sendable {
    case compact
}

enum LibraryRefreshFeedbackAccentColorRole: Equatable, Sendable {
    case purple
}

struct LibraryContentLayout: Equatable, Sendable {
    var refreshFeedbackIsOverlay: Bool
    var contentStartsWithSegmentedControl: Bool

    init(refreshFeedback: LibraryRefreshFeedbackLayout?) {
        self.refreshFeedbackIsOverlay = refreshFeedback?.presentationStyle == .floatingOverlay
        self.contentStartsWithSegmentedControl = true
    }
}

private struct LibraryFilterRow: View {
    @Binding var selection: LibrarySegment

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ToonEdgeSpacing.small) {
                ForEach(LibrarySegment.allCases) { segment in
                    Button {
                        selection = segment
                    } label: {
                        Text(segment.title)
                            .font(ToonEdgeTypography.caption)
                            .padding(.horizontal, ToonEdgeSpacing.medium)
                            .padding(.vertical, ToonEdgeSpacing.small)
                            .background(selection == segment ? ToonEdgeColor.accentSoft : ToonEdgeColor.panel)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selection == segment ? ToonEdgeColor.accent.opacity(0.45) : ToonEdgeColor.border))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, ToonEdgeSpacing.xsmall)
        }
    }
}

private struct LibraryViewModeControl: View {
    @Binding var selection: LibraryViewMode

    var body: some View {
        HStack(spacing: ToonEdgeSpacing.small) {
            ForEach(LibraryViewMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Image(systemName: mode.systemImage)
                        .frame(width: 34, height: 30)
                        .background(selection == mode ? ToonEdgeColor.panel : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == mode ? ToonEdgeColor.textPrimary : ToonEdgeColor.textSecondary)
                .accessibilityLabel("\(mode.title) library view")
            }
        }
        .padding(ToonEdgeSpacing.xsmall)
        .background(ToonEdgeColor.elevated, in: Capsule())
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct LibraryEmptyStateLayout: Equatable, Sendable {
    var isVisible: Bool
    var message: String
    var imageName: String
    var imageURL: URL?

    init(hasLoadedSnapshot: Bool, visibleSeries: [LibrarySeriesSummary]) {
        self.isVisible = hasLoadedSnapshot && visibleSeries.isEmpty
        self.message = "Nothing saved"
        self.imageName = ToonEdgeAppCoreResources.sleepyLibraryEmptyImageName
        self.imageURL = ToonEdgeAppCoreResources.urlForImage(named: imageName, extension: "png")
    }
}

enum ToonEdgeAppCoreResources {
    static let sleepyLibraryEmptyImageName = "sleepy transparent"

    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle.main
        #endif
    }

    static func urlForImage(named name: String, extension fileExtension: String) -> URL? {
        bundle.url(forResource: name, withExtension: fileExtension, subdirectory: "Images")
            ?? bundle.url(forResource: name, withExtension: fileExtension)
    }
}

private struct LibraryRefreshFeedback: Equatable {
    let id = UUID()
    let layout: LibraryRefreshFeedbackLayout

    init(message: String) {
        self.layout = LibraryRefreshFeedbackLayout(message: message)
    }
}

private struct LibrarySummaryPill: View {
    let layout: LibrarySummaryPillLayout
    let refresh: () -> Void

    var body: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            Image(systemName: "books.vertical")
                .foregroundStyle(ToonEdgeColor.accent)

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text(layout.title)
                    .font(ToonEdgeTypography.sectionTitle)
                Text(layout.message)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
            }

            Spacer(minLength: ToonEdgeSpacing.medium)

            if layout.refreshButtonIsVisible {
                Button(action: refresh) {
                    Image(systemName: layout.refreshSystemImage)
                        .frame(width: 36, height: 36)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .disabled(layout.refreshSystemImage == "hourglass")
                .accessibilityLabel(layout.refreshAccessibilityLabel)
            }
        }
        .padding(.horizontal, ToonEdgeSpacing.large)
        .padding(.vertical, ToonEdgeSpacing.medium)
        .background(ToonEdgeColor.panel, in: Capsule())
        .overlay(Capsule().stroke(ToonEdgeColor.border))
    }
}

private struct LibraryRefreshFeedbackView: View {
    let layout: LibraryRefreshFeedbackLayout
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: ToonEdgeSpacing.small) {
            Image(systemName: "arrow.clockwise")
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(accentColor)
                .frame(width: 24, height: 24)
                .background(accentColor.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text(layout.title)
                    .font(ToonEdgeTypography.caption)
                Text(layout.message)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
            }

            Spacer(minLength: ToonEdgeSpacing.small)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(ToonEdgeTypography.caption)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(layout.dismissAccessibilityLabel)
        }
        .padding(.horizontal, ToonEdgeSpacing.medium)
        .padding(.vertical, ToonEdgeSpacing.small)
        .frame(maxWidth: layout.maximumWidth)
        .background(ToonEdgeColor.accentSoft.opacity(0.72), in: RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
        .overlay(RoundedRectangle(cornerRadius: ToonEdgeRadius.small).stroke(accentColor.opacity(0.38)))
    }

    private var accentColor: Color {
        switch layout.accentColorRole {
        case .purple:
            return ToonEdgeColor.accent
        }
    }
}

private struct LibraryEmptyStateView: View {
    let layout: LibraryEmptyStateLayout

    var body: some View {
        VStack(spacing: ToonEdgeSpacing.medium) {
            LibraryMascotImage(url: layout.imageURL)
                .frame(width: 180, height: 160)

            Text(layout.message)
                .font(ToonEdgeTypography.sectionTitle)
                .foregroundStyle(ToonEdgeColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 360)
        .accessibilityElement(children: .combine)
    }
}

private struct LibraryMascotImage: View {
    let url: URL?

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                fallback
            }
            #elseif canImport(AppKit)
            if let url, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                fallback
            }
            #else
            fallback
            #endif
        }
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Image(systemName: "moon.zzz.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(ToonEdgeColor.accent)
            .padding(ToonEdgeSpacing.xxlarge)
    }
}

private struct SeriesCard: View {
    let series: LibrarySeriesSummary
    let layout: LibrarySeriesCardLayout
    private var content: LibrarySeriesCardContent {
        LibrarySeriesCardContent(series: series)
    }

    var body: some View {
        TECard {
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                coverSlot

                VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                    HStack(alignment: .top, spacing: ToonEdgeSpacing.small) {
                        Text(series.title)
                            .font(ToonEdgeTypography.body.weight(.semibold))
                            .lineLimit(layout.titleLineLimit)
                            .multilineTextAlignment(.leading)
                            .frame(height: layout.titleHeight, alignment: .topLeading)

                        Spacer(minLength: 0)
                    }

                    Text(content.metadata)
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                        .lineLimit(layout.metadataLineLimit)
                        .frame(height: layout.metadataHeight, alignment: .leading)
                }

                Spacer(minLength: 0)

                ProgressView(value: series.progressPercent)
                    .tint(progressTint)
                    .frame(height: layout.progressHeight)

                HStack(spacing: ToonEdgeSpacing.xsmall) {
                    if series.hasUnreadUpdates {
                        TEChip("New", isActive: true)
                    }

                    if series.isCompleted {
                        TEChip("Complete")
                    } else if let latestChapterLabel = series.latestChapterLabel {
                        TEChip("Ch. \(latestChapterLabel)")
                    }
                }
                .frame(height: layout.badgeRowHeight, alignment: .leading)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(height: layout.fixedCardHeight)
    }

    @ViewBuilder
    private var coverSlot: some View {
        if layout.coverSlotUsesFullCardWidth {
            decoratedCover
                .frame(width: layout.coverImageWidth, height: layout.coverHeight)
                .frame(maxWidth: .infinity, minHeight: layout.coverSlotHeight, maxHeight: layout.coverSlotHeight, alignment: layout.coverImageAlignment.swiftUIAlignment)
        } else {
            decoratedCover
                .frame(width: layout.coverImageWidth, height: layout.coverHeight)
                .frame(width: layout.coverImageWidth, height: layout.coverSlotHeight, alignment: layout.coverImageAlignment.swiftUIAlignment)
        }
    }

    private var decoratedCover: some View {
        CachedCoverArtwork(url: series.coverImageURL) {
            MissingCoverView(title: series.title)
        }
        .frame(width: layout.coverImageWidth, height: layout.coverHeight)
        .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(ToonEdgeColor.border.opacity(0.65))
        )
    }

    private var progressTint: Color {
        series.hasUnreadUpdates ? ToonEdgeColor.success : ToonEdgeColor.accent
    }
}

private struct SeriesListRow: View {
    let series: LibrarySeriesSummary
    private let layout = LibrarySeriesListRowLayout.default
    private var content: LibrarySeriesCardContent {
        LibrarySeriesCardContent(series: series)
    }

    var body: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            CachedCoverArtwork(url: series.coverImageURL) {
                MissingCoverView(title: series.title)
            }
            .frame(width: layout.coverWidth, height: layout.coverHeight)
            .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text(series.title)
                    .font(ToonEdgeTypography.body.weight(.semibold))
                    .lineLimit(1)
                Text(content.metadata)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .lineLimit(1)
                ProgressView(value: series.progressPercent)
                    .tint(series.hasUnreadUpdates ? ToonEdgeColor.success : ToonEdgeColor.accent)
                    .frame(height: 4)
            }

            Spacer(minLength: ToonEdgeSpacing.small)

            if series.hasUnreadUpdates {
                TEChip("New", isActive: true)
            } else if series.isCompleted {
                TEChip("Done")
            }
        }
        .padding(.vertical, ToonEdgeSpacing.small)
        .padding(.horizontal, ToonEdgeSpacing.small)
        .frame(height: layout.rowHeight)
        .background(ToonEdgeColor.elevated.opacity(0.65), in: RoundedRectangle(cornerRadius: layout.cornerRadius))
    }
}

struct LibrarySeriesCardContent: Equatable, Sendable {
    var metadata: String

    init(series: LibrarySeriesSummary) {
        if let currentChapterLabel = series.currentChapterLabel, !series.isCompleted {
            self.metadata = "Continue Ch. \(currentChapterLabel)"
        } else {
            self.metadata = series.chapterSummaryText
        }
    }
}

struct LibrarySeriesCardLayout: Equatable, Sendable {
    var fixedCardHeight: CGFloat
    var coverAspectRatio: CGFloat
    var coverHeight: CGFloat
    var coverSlotHeight: CGFloat
    var coverImageAlignment: LibrarySeriesCardCoverAlignment
    var coverSlotUsesFullCardWidth: Bool
    var coverAppliesFrameBeforeDecoration: Bool
    var titleLineLimit: Int
    var titleHeight: CGFloat
    var metadataLineLimit: Int
    var metadataHeight: CGFloat
    var progressHeight: CGFloat
    var badgeRowHeight: CGFloat
    var cornerRadius: CGFloat

    static let comfortable = LibrarySeriesCardLayout(
        fixedCardHeight: 350,
        coverAspectRatio: 0.72,
        coverHeight: 180,
        coverSlotHeight: 180,
        coverImageAlignment: .center,
        coverSlotUsesFullCardWidth: true,
        coverAppliesFrameBeforeDecoration: true,
        titleLineLimit: 2,
        titleHeight: 48,
        metadataLineLimit: 1,
        metadataHeight: 18,
        progressHeight: 8,
        badgeRowHeight: 32,
        cornerRadius: 6
    )

    static let compact = LibrarySeriesCardLayout(
        fixedCardHeight: 272,
        coverAspectRatio: 0.72,
        coverHeight: 128,
        coverSlotHeight: 128,
        coverImageAlignment: .center,
        coverSlotUsesFullCardWidth: true,
        coverAppliesFrameBeforeDecoration: true,
        titleLineLimit: 2,
        titleHeight: 42,
        metadataLineLimit: 1,
        metadataHeight: 16,
        progressHeight: 6,
        badgeRowHeight: 28,
        cornerRadius: 5
    )

    static let `default` = comfortable

    func cardHeight(for series: LibrarySeriesSummary) -> CGFloat {
        fixedCardHeight
    }

    var coverImageWidth: CGFloat {
        coverHeight * coverAspectRatio
    }
}

struct LibrarySeriesListRowLayout: Equatable, Sendable {
    var rowHeight: CGFloat
    var coverWidth: CGFloat
    var coverHeight: CGFloat
    var cornerRadius: CGFloat

    static let `default` = LibrarySeriesListRowLayout(
        rowHeight: 82,
        coverWidth: 46,
        coverHeight: 64,
        cornerRadius: 5
    )
}

enum LibrarySeriesCardCoverAlignment: Equatable, Sendable {
    case center

    var swiftUIAlignment: Alignment {
        switch self {
        case .center:
            return .center
        }
    }
}

private struct MissingCoverView: View {
    let title: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ToonEdgeColor.accentSoft, ToonEdgeColor.panel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: ToonEdgeSpacing.small) {
                Image(systemName: "book.pages")
                    .font(.title2)
                    .foregroundStyle(ToonEdgeColor.accent)

                Text(initials)
                    .font(ToonEdgeTypography.title)
                    .foregroundStyle(ToonEdgeColor.textPrimary)
            }
        }
    }

    private var initials: String {
        title
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

private struct SeriesDetailView: View {
    let seriesID: UUID
    let dependencies: AppDependencies
    @Binding var router: AppRouter
    @State private var detail: SeriesDetailSnapshot?
    @State private var chapterListMode: SeriesDetailChapterListMode = .recent
    @State private var hasLoaded = false
    @State private var hasAttemptedChapterIndexRefresh = false
    @State private var cacheFeedback: CacheActionFeedback?
    @State private var pendingSaveDetail: SeriesDetailSnapshot?
    @State private var saveState = AddToLibraryStatePickerModel.defaultState(for: .seriesDetail)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
                if let detail {
                    header(detail)
                    cacheStatus
                    chapterToolbar(detail)
                    chapterList(detail)
                } else if hasLoaded {
                    TEBanner(
                        title: "Series unavailable",
                        message: "This saved title could not be loaded from the mock repository.",
                        systemImage: "exclamationmark.triangle"
                    )
                } else {
                    TEBanner(title: "Loading series", message: "Preparing chapter state.", systemImage: "hourglass")
                }
            }
            .padding(ToonEdgeSpacing.large)
        }
        .navigationTitle("")
        .task {
            await reloadDetail()
            await refreshChapterIndexIfAvailable()
        }
        .onChange(of: router.presentedReader) { oldValue, newValue in
            guard oldValue != nil, newValue == nil else { return }
            Task {
                await reloadDetail()
            }
        }
        .sheet(item: $pendingSaveDetail) { detail in
            AddToLibraryStatePickerView(
                title: detail.title,
                selectedState: $saveState,
                context: .seriesDetail,
                confirm: { state in
                    confirmSave(detail, state: state)
                },
                cancel: {
                    pendingSaveDetail = nil
                }
            )
        }
        .toonEdgeScreen()
    }

    private func header(_ detail: SeriesDetailSnapshot) -> some View {
        let layout = SeriesDetailHeaderLayout(snapshot: detail)
        return VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
            HStack(alignment: .top, spacing: ToonEdgeSpacing.medium) {
                cover(for: detail)
                    .frame(width: 96, height: 132)

                VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                    HStack(spacing: ToonEdgeSpacing.small) {
                        TEChip(detail.status, isActive: detail.hasUnreadUpdates)
                        TEChip(detail.isSaved ? "Saved" : "Follow")
                    }

                    Text(layout.title)
                        .font(ToonEdgeTypography.title)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(layout.metadata)
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                }
            }

            TEButton(layout.primaryActionTitle, systemImage: "play.fill") {
                open(detail.primaryChapter)
            }
            .disabled(detail.primaryChapter == nil)
        }
    }

    @ViewBuilder
    private var cacheStatus: some View {
        if let cacheFeedback {
            TEBanner(
                title: cacheFeedback.isFailure ? "Cache action failed" : "Cache updated",
                message: cacheFeedback.message,
                systemImage: cacheFeedback.isFailure ? "exclamationmark.triangle" : "checkmark.circle"
            )
        }
    }

    private func chapterToolbar(_ detail: SeriesDetailSnapshot) -> some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.medium) {
            HStack {
                Text("Chapters")
                    .font(ToonEdgeTypography.sectionTitle)
                Spacer()
                Menu {
                    Button(detail.isSaved ? "Remove from Library" : "Add to Library") {
                        toggleLibraryMembership(detail)
                    }

                    Divider()

                    Button("Mark Reading") {
                        updateLibraryState(.reading)
                    }
                    Button("Mark Planned") {
                        updateLibraryState(.planned)
                    }
                    Button("Mark Dropped") {
                        updateLibraryState(.dropped)
                    }
                    Button("Mark Completed") {
                        updateLibraryState(.completed)
                    }
                } label: {
                    Image(systemName: detail.isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(ToonEdgeColor.accent)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(detail.isSaved ? "Saved series" : "Save series")
            }

            TESegmentedControl(selection: $chapterListMode) { $0.title }
        }
    }

    @ViewBuilder
    private func chapterList(_ detail: SeriesDetailSnapshot) -> some View {
        let chapters = detail.chapterList(for: chapterListMode)

        if chapters.isEmpty {
            TEBanner(title: "No chapters yet", message: "Chapter metadata will appear here when available.", systemImage: "list.bullet")
        } else {
            VStack(spacing: ToonEdgeSpacing.small) {
                ForEach(chapters) { chapter in
                    Button {
                        open(chapter)
                    } label: {
                        ChapterRow(chapter: chapter)
                    }
                    .buttonStyle(.plain)
                    .disabled(!chapter.isOpenable)
                    .contextMenu {
                        if chapter.isOpenable {
                            Button("Retain Offline", systemImage: "arrow.down.circle") {
                                retain(chapter)
                            }
                        }
                    }
                }
            }
        }
    }

    private func cover(for detail: SeriesDetailSnapshot) -> some View {
        CachedCoverArtwork(url: detail.coverImageURL) {
            MissingCoverView(title: detail.title)
        }
        .clipShape(RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
        .overlay(RoundedRectangle(cornerRadius: ToonEdgeRadius.small).stroke(ToonEdgeColor.border))
    }

    private func reloadDetail() async {
        detail = await dependencies.libraryService.seriesDetail(for: seriesID)
        hasLoaded = true
    }

    private func refreshChapterIndexIfAvailable() async {
        guard SeriesDetailRefreshBehavior.shouldAttemptRefresh(
            hasAttemptedChapterIndexRefresh: hasAttemptedChapterIndexRefresh,
            chapterIndexRefreshService: dependencies.chapterIndexRefreshService
        ) else {
            return
        }

        hasAttemptedChapterIndexRefresh = true
        let outcome = await dependencies.chapterIndexRefreshService?.refreshChapterIndex(for: seriesID)
        if SeriesDetailRefreshBehavior.shouldReloadDetail(after: outcome) {
            await reloadDetail()
        }
    }

    private func open(_ chapter: ChapterSummary?) {
        guard let chapter, chapter.isOpenable else { return }

        Task {
            if let directSession = await dependencies.libraryLifecycleService?.readerSession(forChapterID: chapter.id) {
                var librarySession = directSession
                librarySession.launchOrigin = .library(seriesID: seriesID)
                router.presentReader(librarySession)
                return
            }
            router.presentBrowser(.url(chapter.sourceURL.absoluteString))
        }
    }

    private func toggleLibraryMembership(_ detail: SeriesDetailSnapshot) {
        guard let lifecycleService = dependencies.libraryLifecycleService else { return }

        Task {
            if detail.isSaved {
                try? await lifecycleService.removeFromLibrary(seriesID: detail.id)
                self.detail = nil
            } else {
                saveState = AddToLibraryStatePickerModel.defaultState(for: .seriesDetail)
                pendingSaveDetail = detail
            }
        }
    }

    private func confirmSave(_ detail: SeriesDetailSnapshot, state: LibraryCollectionState) {
        guard let lifecycleService = dependencies.libraryLifecycleService else { return }
        pendingSaveDetail = nil
        var input = detail.libraryInput
        input.libraryState = state

        Task {
            try? await lifecycleService.addToLibrary(input, context: .seriesDetail)
            self.detail = await dependencies.libraryService.seriesDetail(for: detail.id)
        }
    }

    private func updateLibraryState(_ state: LibraryCollectionState) {
        guard let lifecycleService = dependencies.libraryLifecycleService else { return }

        Task {
            try? await lifecycleService.updateLibraryState(state, for: seriesID)
            detail = await dependencies.libraryService.seriesDetail(for: seriesID)
        }
    }

    private func retain(_ chapter: ChapterSummary) {
        Task {
            do {
                let result = try await dependencies.cacheMetadataService.updateCacheRetention(
                    for: chapter.sourceURL,
                    retentionState: .retained,
                    cachedAt: Date()
                )
                cacheFeedback = .success(result)
                detail = await dependencies.libraryService.seriesDetail(for: seriesID)
            } catch {
                cacheFeedback = .failure("Could not retain this chapter offline.")
            }
        }
    }
}

struct SeriesDetailHeaderLayout: Equatable, Sendable {
    var title: String
    var metadata: String
    var synopsisText: String?
    var primaryActionTitle: String

    init(snapshot: SeriesDetailSnapshot) {
        self.title = snapshot.title
        self.metadata = "\(snapshot.sourceDomain) • \(snapshot.chaptersRead)/\(snapshot.totalKnownChapters ?? snapshot.chapters.count) chapters"
        self.synopsisText = nil
        self.primaryActionTitle = snapshot.primaryActionTitle
    }
}

struct SeriesDetailRefreshBehavior {
    static func shouldAttemptRefresh(
        hasAttemptedChapterIndexRefresh: Bool,
        chapterIndexRefreshService: (any SeriesChapterIndexRefreshing)?
    ) -> Bool {
        !hasAttemptedChapterIndexRefresh && chapterIndexRefreshService != nil
    }

    static func shouldReloadDetail(after outcome: ChapterIndexRefreshOutcome?) -> Bool {
        outcome?.didRefresh == true
    }
}

private extension SeriesDetailSnapshot {
    var libraryInput: LibrarySeriesInput {
        LibrarySeriesInput(
            id: id,
            title: title,
            canonicalURL: canonicalURL,
            sourceDomain: sourceDomain,
            coverImageURL: coverImageURL,
            status: status,
            synopsis: synopsis,
            latestKnownChapterLabel: chapters.max { lhs, rhs in
                (lhs.chapterNumber ?? .leastNonzeroMagnitude) < (rhs.chapterNumber ?? .leastNonzeroMagnitude)
            }?.chapterLabel,
            libraryState: libraryState,
            chapters: chapters.map {
                LibraryChapterInput(
                    id: $0.id,
                    title: $0.title,
                    chapterLabel: $0.chapterLabel,
                    chapterNumber: $0.chapterNumber,
                    sourceURL: $0.sourceURL,
                    imageURLs: [],
                    publishedAt: $0.publishedAt
                )
            }
        )
    }

    private var canonicalURL: URL {
        chapters.first?.sourceURL.deletingLastPathComponent()
            ?? URL(string: "https://\(sourceDomain)")!
    }
}

private struct ChapterRow: View {
    let chapter: ChapterSummary

    var body: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            stateMark

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text(chapter.title)
                    .font(ToonEdgeTypography.body.weight(.semibold))
                    .foregroundStyle(ToonEdgeColor.textPrimary)

                Text(subtitle)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: ToonEdgeSpacing.xsmall) {
                TEChip(chapter.readState.displayLabel, isActive: isPrimaryState)

                if chapter.isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.success)
                        .accessibilityLabel("Downloaded")
                }
            }
        }
        .padding(ToonEdgeSpacing.large)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: ToonEdgeRadius.medium)
                .stroke(rowBorder)
        )
    }

    private var stateMark: some View {
        Image(systemName: stateIcon)
            .font(ToonEdgeTypography.body.weight(.semibold))
            .foregroundStyle(stateColor)
            .frame(width: 32, height: 32)
            .background(stateColor.opacity(0.16), in: Circle())
    }

    private var subtitle: String {
        if !chapter.isOpenable {
            return "Chapter \(chapter.chapterLabel) • Unavailable"
        }

        if let downloadLabel = chapter.downloadLabel {
            return "Chapter \(chapter.chapterLabel) • \(downloadLabel)"
        } else {
            return "Chapter \(chapter.chapterLabel)"
        }
    }

    private var isPrimaryState: Bool {
        switch chapter.readState {
        case .new, .inProgress:
            true
        case .unread, .read:
            false
        }
    }

    private var rowBackground: Color {
        switch chapter.readState {
        case .new:
            ToonEdgeColor.success.opacity(0.14)
        case .inProgress:
            ToonEdgeColor.accentSoft
        case .unread:
            ToonEdgeColor.elevated
        case .read:
            ToonEdgeColor.panel
        }
    }

    private var rowBorder: Color {
        chapter.isDownloaded ? ToonEdgeColor.success.opacity(0.55) : ToonEdgeColor.border
    }

    private var stateColor: Color {
        switch chapter.readState {
        case .new:
            ToonEdgeColor.success
        case .inProgress:
            ToonEdgeColor.accent
        case .unread:
            ToonEdgeColor.textSecondary
        case .read:
            ToonEdgeColor.textPrimary.opacity(0.72)
        }
    }

    private var stateIcon: String {
        switch chapter.readState {
        case .new:
            "sparkle"
        case .inProgress:
            "play.fill"
        case .unread:
            "circle"
        case .read:
            "checkmark.circle.fill"
        }
    }
}
