import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum LibraryContentPhase: Equatable, Sendable {
    case loading
    case empty
    case content

    public init(hasLoadedSnapshot: Bool, visibleCount: Int) {
        if !hasLoadedSnapshot {
            self = .loading
        } else if visibleCount == 0 {
            self = .empty
        } else {
            self = .content
        }
    }
}

enum LibraryEmptyReason: Equatable, Sendable {
    case collection
    case filter

    init(totalCount: Int, visibleCount: Int) {
        self = totalCount == 0 && visibleCount == 0 ? .collection : .filter
    }

    var message: String {
        switch self {
        case .collection:
            "Nothing saved"
        case .filter:
            "No titles in this section"
        }
    }
}

struct LibraryDensityPresentation: Equatable, Sendable {
    var savedPreference: LibraryViewMode
    var renderedMode: LibraryViewMode

    init(saved: LibraryViewMode, accessibilityText: Bool) {
        self.savedPreference = saved
        self.renderedMode = accessibilityText ? .list : saved
    }
}

public struct LibraryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let dependencies: AppDependencies
    @Binding private var router: AppRouter
    @State private var snapshot = LibrarySnapshot(series: [])
    @State private var selectedSegment: LibrarySegment = .recent
    @State private var selectedViewMode: LibraryViewMode
    @State private var hasLoadedSnapshot = false
    @State private var isRefreshingUpdates = false
    @State private var refreshFeedback: LibraryRefreshFeedback?
    @State private var navigationPath: [LibrarySeriesDetailRoute] = []
    @State private var seriesDetailCache: [UUID: SeriesDetailSnapshot] = [:]
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
                    LibraryFilterRow(selection: $selectedSegment) { segment in
                        selectSegment(segment)
                    }
                    if hasLoadedSnapshot {
                        collectionControls
                    }
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
                    navigationPath = [LibrarySeriesDetailRoute(seriesID: seriesID)]
                }
            }
            .onChange(of: router.pendingLibrarySegment) { _, pendingSegment in
                guard let pendingSegment else { return }
                selectedSegment = pendingSegment
                _ = router.consumePendingLibrarySegment()
            }
            .onChange(of: router.pendingLibrarySeriesID) { _, pendingSeriesID in
                guard let pendingSeriesID else { return }
                navigationPath = [LibrarySeriesDetailRoute(seriesID: pendingSeriesID)]
                _ = router.consumePendingLibrarySeriesID()
            }
            .refreshable {
                await refreshUpdates()
            }
            .onChange(of: selectedViewMode) { _, mode in
                libraryViewPreferences.selectedViewMode = mode
            }
            .navigationDestination(for: LibrarySeriesDetailRoute.self) { route in
                SeriesDetailView(
                    seriesID: route.seriesID,
                    seedSummary: route.seedSummary,
                    cachedDetail: seriesDetailCache[route.seriesID],
                    dependencies: dependencies,
                    router: $router,
                    onDetailHydrated: { hydratedDetail in
                        if let hydratedDetail {
                            seriesDetailCache[route.seriesID] = hydratedDetail
                        } else {
                            seriesDetailCache.removeValue(forKey: route.seriesID)
                        }
                    }
                )
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

    private var collectionControls: some View {
        let visible = snapshot.series(for: selectedSegment)
        let layout = LibraryCollectionControlsLayout(
            visibleSeries: visible,
            hasUpdateRefreshService: dependencies.updateRefreshService != nil,
            isRefreshing: isRefreshingUpdates
        )

        return LibraryCollectionControls(
            layout: layout,
            selection: $selectedViewMode,
            selectViewMode: { mode in selectViewMode(mode) }
        ) {
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
        showRefreshFeedback(result: result)
        if let event = InteractionFeedbackOutcomePolicy.updateEvent(for: result, userInitiated: true) {
            dependencies.interactionFeedback.emit(event)
        }
    }

    private func selectSegment(_ segment: LibrarySegment) {
        guard selectedSegment != segment else { return }
        selectedSegment = segment
        if let event = InteractionFeedbackOutcomePolicy.selectionEvent(valueChanged: true) {
            dependencies.interactionFeedback.emit(event)
        }
    }

    private func selectViewMode(_ mode: LibraryViewMode) {
        guard selectedViewMode != mode else { return }
        selectedViewMode = mode
        if let event = InteractionFeedbackOutcomePolicy.selectionEvent(valueChanged: true) {
            dependencies.interactionFeedback.emit(event)
        }
    }

    @ViewBuilder
    private var content: some View {
        let visible = snapshot.series(for: selectedSegment)
        let emptyLayout = LibraryEmptyStateLayout(
            hasLoadedSnapshot: hasLoadedSnapshot,
            totalCount: snapshot.series.count,
            visibleSeries: visible
        )

        switch LibraryContentPhase(hasLoadedSnapshot: hasLoadedSnapshot, visibleCount: visible.count) {
        case .loading:
            ProgressView("Loading your library")
                .frame(maxWidth: .infinity, minHeight: 180)
                .accessibilityIdentifier("library.loading")
        case .empty:
            LibraryEmptyStateView(layout: emptyLayout)
                .accessibilityIdentifier("library.empty")
        case .content:
            collection(visible, mode: LibraryDensityPresentation(
                saved: selectedViewMode,
                accessibilityText: dynamicTypeSize.isAccessibilitySize
            ).renderedMode)
        }
    }

    @ViewBuilder
    private func collection(_ visible: [LibrarySeriesSummary], mode: LibraryViewMode) -> some View {
        if mode == .list {
            LazyVStack(spacing: 0) {
                ForEach(visible) { series in
                    NavigationLink(value: LibrarySeriesDetailRoute(summary: series)) {
                        SeriesListRow(series: series)
                    }
                    .buttonStyle(.plain)

                    if series.id != visible.last?.id {
                        Divider().padding(.leading, LibrarySeriesListRowLayout.default.coverWidth + ToonEdgeSpacing.medium)
                    }
                }
            }
        } else {
            let gridLayout = LibraryGridLayout(mode: mode)
            LazyVGrid(columns: gridLayout.columns, spacing: gridLayout.itemSpacing) {
                ForEach(visible) { series in
                    NavigationLink(value: LibrarySeriesDetailRoute(summary: series)) {
                        if mode == .comfortable {
                            SeriesCard(series: series, layout: .comfortable)
                        } else {
                            SeriesCompactTile(series: series, layout: .compact)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func showRefreshFeedback(result: LibraryUpdateRefreshResult) {
        let feedback = LibraryRefreshFeedback(result: result)
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

struct LibrarySeriesDetailRoute: Hashable, Sendable {
    var seriesID: UUID
    var seedSummary: LibrarySeriesSummary?

    init(seriesID: UUID, seedSummary: LibrarySeriesSummary? = nil) {
        self.seriesID = seriesID
        self.seedSummary = seedSummary
    }

    init(summary: LibrarySeriesSummary) {
        self.seriesID = summary.id
        self.seedSummary = summary
    }

    static func == (lhs: LibrarySeriesDetailRoute, rhs: LibrarySeriesDetailRoute) -> Bool {
        lhs.seriesID == rhs.seriesID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(seriesID)
    }
}

struct LibraryCollectionControlsLayout: Equatable, Sendable {
    var refreshButtonIsVisible: Bool
    var refreshSystemImage: String
    var refreshAccessibilityLabel: String
    var countText: String
    var usesLargeSummaryCard: Bool

    init(
        visibleSeries: [LibrarySeriesSummary],
        hasUpdateRefreshService: Bool,
        isRefreshing: Bool
    ) {
        self.refreshButtonIsVisible = hasUpdateRefreshService
        self.refreshSystemImage = isRefreshing ? "hourglass" : "arrow.clockwise"
        self.refreshAccessibilityLabel = "Check for new chapters"
        self.countText = "\(visibleSeries.count) \(visibleSeries.count == 1 ? "title" : "titles")"
        self.usesLargeSummaryCard = false
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

    init(result: LibraryUpdateRefreshResult) {
        let feedback = LibraryRefreshFeedbackPresentation(result: result)
        self.title = feedback.title
        self.message = feedback.message
        self.presentationStyle = .floatingOverlay
        self.overlayAlignment = .bottomTrailing
        self.maximumWidth = 280
        self.contentSize = .compact
        self.accentColorRole = feedback.accentColorRole
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
    case success
    case warning
    case failure
}

struct LibraryRefreshFeedbackPresentation: Equatable, Sendable {
    var title: String
    var message: String
    var accentColorRole: LibraryRefreshFeedbackAccentColorRole

    init(result: LibraryUpdateRefreshResult) {
        self.message = "\(result.checkedCount) checked, \(result.updatedCount) \(result.updatedCount == 1 ? "update" : "updates")"
        if result.failedCount == result.checkedCount, result.checkedCount > 0 {
            self.title = "Update check failed"
            self.accentColorRole = .failure
        } else if result.failedCount > 0 {
            self.title = "Some updates unavailable"
            self.message += ", \(result.failedCount) failed"
            self.accentColorRole = .warning
        } else if result.updatedCount > 0 {
            self.title = "Updates found"
            self.accentColorRole = .success
        } else {
            self.title = "No new chapters"
            self.accentColorRole = .purple
        }
    }
}

struct LibraryContentLayout: Equatable, Sendable {
    var refreshFeedbackIsOverlay: Bool
    var contentStartsWithSegmentedControl: Bool

    init(refreshFeedback: LibraryRefreshFeedbackLayout?) {
        self.refreshFeedbackIsOverlay = refreshFeedback?.presentationStyle == .floatingOverlay
        self.contentStartsWithSegmentedControl = true
    }
}

struct LibraryGridLayout: Equatable, Sendable {
    var columnStyle: LibraryGridColumnStyle
    var itemSpacing: CGFloat
    var horizontalContentPadding: CGFloat

    init(mode: LibraryViewMode) {
        switch mode {
        case .comfortable:
            self.columnStyle = .fixedCount(2)
            self.itemSpacing = ToonEdgeSpacing.large
            self.horizontalContentPadding = ToonEdgeSpacing.large
        case .compact:
            self.columnStyle = .fixedCount(4)
            self.itemSpacing = ToonEdgeSpacing.small
            self.horizontalContentPadding = ToonEdgeSpacing.medium
        case .list:
            self.columnStyle = .adaptiveMinimum(320)
            self.itemSpacing = ToonEdgeSpacing.small
            self.horizontalContentPadding = ToonEdgeSpacing.large
        }
    }

    var columns: [GridItem] {
        switch columnStyle {
        case .fixedCount(let count):
            return Array(
                repeating: GridItem(.flexible(), spacing: itemSpacing, alignment: .top),
                count: count
            )
        case .adaptiveMinimum(let minimum):
            return [GridItem(.adaptive(minimum: minimum), spacing: itemSpacing, alignment: .top)]
        }
    }
}

enum LibraryGridColumnStyle: Equatable, Sendable {
    case fixedCount(Int)
    case adaptiveMinimum(CGFloat)
}

struct LibraryFilterChipLayout: Equatable, Sendable {
    var cornerRadius: CGFloat
    var usesCapsuleShape: Bool
    var backgroundOpacity: Double

    init(isSelected: Bool) {
        self.cornerRadius = 8
        self.usesCapsuleShape = false
        self.backgroundOpacity = isSelected ? 1 : 0.72
    }
}

private struct LibraryFilterRow: View {
    @Binding var selection: LibrarySegment
    let select: (LibrarySegment) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ToonEdgeSpacing.small) {
                ForEach(LibrarySegment.allCases) { segment in
                    Button {
                        select(segment)
                    } label: {
                        let layout = LibraryFilterChipLayout(isSelected: selection == segment)

                        Text(segment.title)
                            .font(ToonEdgeTypography.caption)
                            .padding(.horizontal, ToonEdgeSpacing.medium)
                            .padding(.vertical, ToonEdgeSpacing.small)
                            .background(
                                selection == segment ? ToonEdgeColor.accentSoft : ToonEdgeColor.panel.opacity(layout.backgroundOpacity),
                                in: RoundedRectangle(cornerRadius: layout.cornerRadius)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: layout.cornerRadius)
                                    .stroke(selection == segment ? ToonEdgeColor.accent.opacity(0.45) : ToonEdgeColor.border.opacity(0.5))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == segment ? .isSelected : [])
                    .accessibilityValue(selection == segment ? "Selected" : "Not selected")
                }
            }
            .padding(.vertical, ToonEdgeSpacing.xsmall)
        }
    }
}

private struct LibraryViewModeControl: View {
    @Binding var selection: LibraryViewMode
    let select: (LibraryViewMode) -> Void

    var body: some View {
        HStack(spacing: ToonEdgeSpacing.small) {
            ForEach(LibraryViewMode.allCases) { mode in
                Button {
                    select(mode)
                } label: {
                    Image(systemName: mode.systemImage)
                        .frame(width: 44, height: 44)
                        .background(selection == mode ? ToonEdgeColor.panel : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == mode ? ToonEdgeColor.textPrimary : ToonEdgeColor.textSecondary)
                .accessibilityLabel("\(mode.title) library view")
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
                .accessibilityValue(selection == mode ? "Selected" : "Not selected")
            }
        }
        .padding(ToonEdgeSpacing.xsmall)
        .background(ToonEdgeColor.elevated.opacity(0.72), in: RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct LibraryEmptyStateLayout: Equatable, Sendable {
    var isVisible: Bool
    var message: String
    var imageName: String
    var imageURL: URL?

    init(hasLoadedSnapshot: Bool, totalCount: Int = 0, visibleSeries: [LibrarySeriesSummary]) {
        self.isVisible = hasLoadedSnapshot && visibleSeries.isEmpty
        self.message = LibraryEmptyReason(totalCount: totalCount, visibleCount: visibleSeries.count).message
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

    init(result: LibraryUpdateRefreshResult) {
        self.layout = LibraryRefreshFeedbackLayout(result: result)
    }
}

private struct LibraryCollectionControls: View {
    let layout: LibraryCollectionControlsLayout
    @Binding var selection: LibraryViewMode
    let selectViewMode: (LibraryViewMode) -> Void
    let refresh: () -> Void

    var body: some View {
        HStack(spacing: ToonEdgeSpacing.small) {
            Text(layout.countText)
                .font(ToonEdgeTypography.caption.weight(.semibold))
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .lineLimit(1)

            Spacer(minLength: ToonEdgeSpacing.small)

            LibraryViewModeControl(selection: $selection, select: selectViewMode)

            if layout.refreshButtonIsVisible {
                Button(action: refresh) {
                    Image(systemName: layout.refreshSystemImage)
                        .frame(width: 44, height: 44)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .disabled(layout.refreshSystemImage == "hourglass")
                .accessibilityLabel(layout.refreshAccessibilityLabel)
            }
        }
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
        case .success:
            return ToonEdgeColor.success
        case .warning:
            return ToonEdgeColor.warning
        case .failure:
            return ToonEdgeColor.failure
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
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
            coverSlot

            Text(series.title)
                .font(ToonEdgeTypography.body.weight(.semibold))
                .lineLimit(layout.titleLineLimit)
                .multilineTextAlignment(.leading)
                .frame(height: layout.titleHeight, alignment: .topLeading)

            Text(content.sourceMetadata)
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .lineLimit(layout.metadataLineLimit)
                .frame(height: layout.metadataHeight, alignment: .leading)

            ProgressView(value: series.progressPercent)
                .tint(progressTint)
                .frame(height: layout.progressHeight)

            HStack(spacing: ToonEdgeSpacing.xsmall) {
                if series.hasUnreadUpdates {
                    TEChip("New", isActive: true)
                }

                if let comfortableBadgeMetadata = content.comfortableBadgeMetadata {
                    TEChip(comfortableBadgeMetadata)
                }
            }
            .frame(height: layout.badgeRowHeight, alignment: .leading)
        }
        .frame(height: layout.fixedCardHeight, alignment: .top)
        .contentShape(Rectangle())
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
    }

    private var progressTint: Color {
        series.hasUnreadUpdates ? ToonEdgeColor.success : ToonEdgeColor.accent
    }
}

private struct SeriesCompactTile: View {
    let series: LibrarySeriesSummary
    let layout: LibrarySeriesCardLayout
    private var content: LibrarySeriesCardContent {
        LibrarySeriesCardContent(series: series)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
            CachedCoverArtwork(url: series.coverImageURL) {
                MissingCoverView(title: series.title)
            }
            .aspectRatio(1, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: layout.coverHeight)
            .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))

            Text(series.title)
                .font(ToonEdgeTypography.caption.weight(.semibold))
                .lineLimit(1)
                .frame(height: layout.titleHeight, alignment: .topLeading)

            Text(content.compactMetadata)
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(series.hasUnreadUpdates ? ToonEdgeColor.success : ToonEdgeColor.textSecondary)
                .lineLimit(1)
                .frame(height: layout.metadataHeight, alignment: .leading)
        }
        .frame(height: layout.fixedCardHeight, alignment: .top)
        .contentShape(Rectangle())
    }
}

private struct SeriesListRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let series: LibrarySeriesSummary
    private var content: LibrarySeriesCardContent {
        LibrarySeriesCardContent(series: series)
    }
    private var layout: LibrarySeriesListRowLayout {
        LibrarySeriesListRowLayout(accessibilityText: dynamicTypeSize.isAccessibilitySize)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                    leadingContent
                    statusBadge
                }
            } else {
                HStack(spacing: ToonEdgeSpacing.medium) {
                    leadingContent
                    Spacer(minLength: ToonEdgeSpacing.small)
                    statusBadge
                }
            }
        }
        .padding(.vertical, ToonEdgeSpacing.small)
        .padding(.horizontal, ToonEdgeSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: layout.rowHeight)
        .contentShape(Rectangle())
    }

    private var leadingContent: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            CachedCoverArtwork(url: series.coverImageURL) {
                MissingCoverView(title: series.title)
            }
            .frame(width: layout.coverWidth, height: layout.coverHeight)
            .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text(series.title)
                    .font(ToonEdgeTypography.body.weight(.semibold))
                    .lineLimit(layout.textLineLimit)
                Text(content.listMetadata)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .lineLimit(layout.textLineLimit)
                ProgressView(value: series.progressPercent)
                    .tint(series.hasUnreadUpdates ? ToonEdgeColor.success : ToonEdgeColor.accent)
                    .frame(height: 4)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if series.hasUnreadUpdates {
            TEChip("New", isActive: true)
        } else if series.isCompleted {
            TEChip("Done")
        }
    }
}

struct LibrarySeriesCardContent: Equatable, Sendable {
    var metadata: String
    var compactMetadata: String
    var sourceMetadata: String
    var listMetadata: String
    var comfortableBadgeMetadata: String?

    init(series: LibrarySeriesSummary) {
        let resumeBadge = Self.chapterBadgeLabel(from: series.resumeTarget?.chapter)
        let currentBadge: String?
        if let currentChapterLabel = series.currentChapterLabel, !series.isCompleted {
            currentBadge = Self.chapterBadgeLabel(from: currentChapterLabel)
        } else {
            currentBadge = nil
        }

        if let resumeBadge {
            self.metadata = "Continue \(resumeBadge)"
        } else if let currentBadge {
            self.metadata = "Continue \(currentBadge)"
        } else {
            self.metadata = series.chapterSummaryText
        }

        if let resumeBadge {
            self.compactMetadata = resumeBadge
        } else if let currentBadge {
            self.compactMetadata = currentBadge
        } else {
            self.compactMetadata = series.chapterSummaryText
        }

        let sourceDomain = Self.normalizedDomain(series.sourceDomain)
        if !sourceDomain.isEmpty {
            self.sourceMetadata = sourceDomain
        } else if let canonicalURL = series.canonicalURL {
            let canonicalHost = Self.normalizedDomain(canonicalURL.host ?? "")
            self.sourceMetadata = canonicalHost.isEmpty ? series.chapterSummaryText : canonicalHost
        } else {
            self.sourceMetadata = series.chapterSummaryText
        }

        if series.isCompleted {
            self.comfortableBadgeMetadata = "Complete"
        } else if let resumeBadge {
            self.comfortableBadgeMetadata = resumeBadge
        } else if let currentBadge {
            self.comfortableBadgeMetadata = currentBadge
        } else {
            self.comfortableBadgeMetadata = nil
        }

        if let resumeBadge {
            self.listMetadata = resumeBadge
        } else if let currentBadge {
            self.listMetadata = currentBadge
        } else {
            self.listMetadata = metadata
        }
    }

    private static func normalizedDomain(_ domain: String) -> String {
        domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func chapterBadgeLabel(from label: String) -> String? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isNumericChapterLabel(trimmed) else { return nil }
        return "Ch. \(trimmed)"
    }

    private static func chapterBadgeLabel(from chapter: ChapterSummary?) -> String? {
        guard let chapter else { return nil }
        let label = ChapterNumericLabelExtractor.label(for: chapter) ?? chapter.chapterLabel
        return chapterBadgeLabel(from: label)
    }

    private static func isNumericChapterLabel(_ label: String) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let decimalParts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard decimalParts.count == 1 || decimalParts.count == 2 else { return false }
        return decimalParts.allSatisfy { part in !part.isEmpty && part.allSatisfy { character in character.isNumber } }
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
    var usesOuterCardContainer: Bool

    static let comfortable = LibrarySeriesCardLayout(
        fixedCardHeight: 318,
        coverAspectRatio: 0.72,
        coverHeight: 190,
        coverSlotHeight: 190,
        coverImageAlignment: .center,
        coverSlotUsesFullCardWidth: true,
        coverAppliesFrameBeforeDecoration: true,
        titleLineLimit: 2,
        titleHeight: 46,
        metadataLineLimit: 1,
        metadataHeight: 18,
        progressHeight: 4,
        badgeRowHeight: 24,
        cornerRadius: 4,
        usesOuterCardContainer: false
    )

    static let compact = LibrarySeriesCardLayout(
        fixedCardHeight: 142,
        coverAspectRatio: 1,
        coverHeight: 76,
        coverSlotHeight: 76,
        coverImageAlignment: .center,
        coverSlotUsesFullCardWidth: true,
        coverAppliesFrameBeforeDecoration: true,
        titleLineLimit: 1,
        titleHeight: 22,
        metadataLineLimit: 1,
        metadataHeight: 16,
        progressHeight: 0,
        badgeRowHeight: 0,
        cornerRadius: 4,
        usesOuterCardContainer: false
    )

    static let `default` = comfortable

    func cardHeight(for series: LibrarySeriesSummary) -> CGFloat {
        fixedCardHeight
    }

    var coverImageWidth: CGFloat {
        coverHeight * coverAspectRatio
    }

    var verticalContentSpacing: CGFloat {
        ToonEdgeSpacing.small * 4
    }

    var minimumRequiredHeight: CGFloat {
        coverSlotHeight
            + titleHeight
            + metadataHeight
            + progressHeight
            + badgeRowHeight
            + verticalContentSpacing
    }
}

struct LibrarySeriesListRowLayout: Equatable, Sendable {
    var rowHeight: CGFloat?
    var coverWidth: CGFloat
    var coverHeight: CGFloat
    var cornerRadius: CGFloat
    var textLineLimit: Int?
    var usesFullWidthHitShape: Bool

    init(accessibilityText: Bool) {
        self.rowHeight = accessibilityText ? nil : 82
        self.coverWidth = 46
        self.coverHeight = 64
        self.cornerRadius = 4
        self.textLineLimit = accessibilityText ? nil : 1
        self.usesFullWidthHitShape = true
    }

    static let `default` = LibrarySeriesListRowLayout(accessibilityText: false)
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

struct MissingCoverView: View {
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

struct LibraryDetailPrewarmPolicy: Equatable, Sendable {
    enum Trigger: Equatable, Sendable {
        case navigationOnly
    }

    var automaticallyPrewarmsVisibleRows: Bool { false }
    var prewarmTrigger: Trigger { .navigationOnly }
}
