import SwiftUI

struct ReaderChapterListRow: Identifiable, Equatable {
    let id: UUID
    let title: String
    let sourceURL: URL
    /// Nil for a neighbor known only by its link, whose reading state hasn't been recorded.
    let readState: ChapterReadState?
    let statusText: String?
    let isCurrent: Bool
    let isDownloaded: Bool
    let isEnabled: Bool
    /// Nil for the current chapter, which has nowhere to jump.
    let direction: ReaderChapterDirection?

    var chapter: MockChapter {
        MockChapter(id: id, title: title, sourceURL: sourceURL)
    }

    var systemImage: String {
        if isCurrent { return "play.fill" }
        switch readState {
        case .new: return "sparkle"
        case .inProgress: return "play.fill"
        case .read: return "checkmark.circle.fill"
        case .unread, nil: return "circle"
        }
    }

    var accessibilityLabel: String {
        [title, statusText, isDownloaded ? "downloaded" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

struct ReaderChapterListModel: Equatable {
    let seriesTitle: String
    /// Nil when the series has no Series Detail page to open.
    let seriesDetailID: UUID?
    let rows: [ReaderChapterListRow]

    var currentRowID: UUID? {
        rows.first(where: \.isCurrent)?.id
    }

    init(session: MockReaderSession, progress: ReaderProgress, detail: SeriesDetailSnapshot?) {
        seriesTitle = detail?.title ?? session.seriesTitle
        seriesDetailID = detail?.id

        var chapters = Array((detail?.chapterList(for: .all) ?? []).reversed())
        var unrecordedIDs = Set<UUID>()

        func insertUnrecorded(title: String, sourceURL: URL, id: UUID, at index: Int) {
            chapters.insert(Self.unrecordedSummary(title: title, sourceURL: sourceURL, id: id), at: index)
            unrecordedIDs.insert(id)
        }

        var currentIndex: Int
        if let match = Self.index(of: session.chapterTitle, sourceURL: session.sourceURL, in: chapters) {
            currentIndex = match
        } else {
            currentIndex = Self.insertionIndex(forTitle: session.chapterTitle, in: chapters)
            insertUnrecorded(title: session.chapterTitle, sourceURL: session.sourceURL, id: session.id, at: currentIndex)
        }

        if let next = session.nextChapter, Self.index(of: next.title, sourceURL: next.sourceURL, in: chapters) == nil {
            insertUnrecorded(title: next.title, sourceURL: next.sourceURL, id: next.id, at: currentIndex)
            currentIndex += 1
        }
        if let previous = session.previousChapter,
           Self.index(of: previous.title, sourceURL: previous.sourceURL, in: chapters) == nil {
            insertUnrecorded(title: previous.title, sourceURL: previous.sourceURL, id: previous.id, at: currentIndex + 1)
        }

        let finalCurrentIndex = currentIndex
        rows = chapters.enumerated().map { index, chapter in
            let isCurrent = index == finalCurrentIndex
            let isRecorded = !unrecordedIDs.contains(chapter.id)
            return ReaderChapterListRow(
                id: chapter.id,
                title: chapter.title,
                sourceURL: chapter.sourceURL,
                readState: isRecorded ? chapter.readState : nil,
                statusText: Self.statusText(for: chapter, isCurrent: isCurrent, isRecorded: isRecorded, progress: progress),
                isCurrent: isCurrent,
                isDownloaded: chapter.isDownloaded,
                isEnabled: isCurrent || chapter.isOpenable,
                direction: isCurrent ? nil : (index < finalCurrentIndex ? .next : .previous)
            )
        }
    }

    private static func statusText(
        for chapter: ChapterSummary,
        isCurrent: Bool,
        isRecorded: Bool,
        progress: ReaderProgress
    ) -> String? {
        if isCurrent {
            return "Reading · \(Int((progress.fractionComplete * 100).rounded()))%"
        }
        guard isRecorded else { return nil }

        let progressPercent: Double
        if case let .inProgress(value) = chapter.readState {
            progressPercent = value
        } else {
            progressPercent = 0
        }
        return ChapterRowPresentation(
            readState: chapter.readState,
            progressPercent: progressPercent,
            isNew: chapter.readState == .new,
            isDownloaded: chapter.isDownloaded,
            isOpenable: chapter.isOpenable
        ).primaryStateText
    }

    private static func index(of title: String, sourceURL: URL, in chapters: [ChapterSummary]) -> Int? {
        if let match = chapters.firstIndex(where: { $0.sourceURL == sourceURL }) {
            return match
        }
        guard let number = chapterNumber(fromTitle: title) else { return nil }
        return chapters.firstIndex { $0.chapterNumber == number }
    }

    /// Keeps newest-first order when the number is known; otherwise the chapter leads the list.
    private static func insertionIndex(forTitle title: String, in chapters: [ChapterSummary]) -> Int {
        guard let number = chapterNumber(fromTitle: title) else { return 0 }
        return chapters.firstIndex { ($0.chapterNumber ?? .infinity) < number } ?? chapters.count
    }

    private static func chapterNumber(fromTitle title: String) -> Double? {
        ChapterNumericLabelExtractor.label(chapterNumber: nil, chapterLabel: "", title: title).flatMap(Double.init)
    }

    private static func unrecordedSummary(title: String, sourceURL: URL, id: UUID) -> ChapterSummary {
        ChapterSummary(
            id: id,
            title: title,
            chapterLabel: title,
            chapterNumber: chapterNumber(fromTitle: title),
            sourceURL: sourceURL,
            readState: .unread,
            isDownloaded: false,
            publishedAt: nil
        )
    }
}

struct ReaderChapterListView: View {
    @ObservedObject var viewModel: ReaderViewModel
    let onSelect: (ReaderChapterListRow) -> Void
    let onOpenSeriesDetails: (UUID) -> Void

    @State private var detail: SeriesDetailSnapshot?
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if hasLoaded {
                content(ReaderChapterListModel(session: viewModel.session, progress: viewModel.progress, detail: detail))
            } else {
                ProgressView("Loading chapters")
                    .font(ToonEdgeTypography.body)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("reader.chapters.loading")
            }
        }
        .task {
            detail = await viewModel.chapterListDetail()
            hasLoaded = true
        }
    }

    private func content(_ model: ReaderChapterListModel) -> some View {
        VStack(spacing: 0) {
            header(model)

            ScrollViewReader { proxy in
                List(model.rows) { row in
                    Button {
                        onSelect(row)
                    } label: {
                        rowLabel(row)
                    }
                    .buttonStyle(.plain)
                    .disabled(!row.isEnabled)
                    .listRowBackground(row.isCurrent ? ToonEdgeColor.accentSoft : Color.clear)
                    .accessibilityLabel(row.accessibilityLabel)
                    .accessibilityAddTraits(row.isCurrent ? .isSelected : [])
                    .accessibilityIdentifier("reader.chapters.row.\(row.title)")
                    .id(row.id)
                }
                .listStyle(.plain)
                .accessibilityIdentifier("reader.chapters.list")
                .onAppear {
                    if let currentRowID = model.currentRowID {
                        proxy.scrollTo(currentRowID, anchor: .center)
                    }
                }
            }
        }
    }

    private func header(_ model: ReaderChapterListModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: ToonEdgeSpacing.medium) {
            Text(model.seriesTitle)
                .font(ToonEdgeTypography.sectionTitle)
                .foregroundStyle(ToonEdgeColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("reader.chapters.title")

            Spacer(minLength: ToonEdgeSpacing.small)

            if let seriesID = model.seriesDetailID {
                Button("Series details") {
                    onOpenSeriesDetails(seriesID)
                }
                .font(ToonEdgeTypography.caption.weight(.semibold))
                .foregroundStyle(ToonEdgeColor.accent)
                .buttonStyle(.plain)
                .frame(minHeight: TEActionMetrics.minimumHitSize)
                .contentShape(Rectangle())
                .accessibilityIdentifier("reader.chapters.seriesDetails")
            }
        }
        .padding(.horizontal, ToonEdgeSpacing.large)
        .padding(.top, ToonEdgeSpacing.xlarge)
        .padding(.bottom, ToonEdgeSpacing.small)
    }

    private func rowLabel(_ row: ReaderChapterListRow) -> some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            Image(systemName: row.systemImage)
                .font(ToonEdgeTypography.body)
                .foregroundStyle(iconColor(row))
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(row.title)
                .font(row.isCurrent ? ToonEdgeTypography.body.weight(.semibold) : ToonEdgeTypography.body)
                .foregroundStyle(row.isEnabled ? ToonEdgeColor.textPrimary : ToonEdgeColor.textSecondary)

            Spacer(minLength: ToonEdgeSpacing.small)

            if row.isDownloaded {
                Image(systemName: "arrow.down.circle.fill")
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.success)
                    .accessibilityHidden(true)
            }

            if let statusText = row.statusText {
                status(statusText, row: row)
            }
        }
        .frame(minHeight: TEActionMetrics.minimumHitSize)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func status(_ text: String, row: ReaderChapterListRow) -> some View {
        let label = Text(text).font(ToonEdgeTypography.caption)
        if row.readState == .new, !row.isCurrent {
            label
                .foregroundStyle(ToonEdgeColor.accent)
                .padding(.horizontal, ToonEdgeSpacing.small)
                .padding(.vertical, ToonEdgeSpacing.xsmall)
                .background(ToonEdgeColor.accentSoft, in: Capsule())
        } else {
            label.foregroundStyle(row.isCurrent ? ToonEdgeColor.accent : ToonEdgeColor.textSecondary)
        }
    }

    private func iconColor(_ row: ReaderChapterListRow) -> Color {
        if row.isCurrent || row.readState == .new {
            return ToonEdgeColor.accent
        }
        return ToonEdgeColor.textSecondary
    }
}
