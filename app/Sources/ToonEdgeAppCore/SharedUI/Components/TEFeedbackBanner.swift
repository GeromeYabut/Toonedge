import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// One transient message shown by the shared feedback banner.
/// Success and info dismiss themselves; warnings and failures wait for the reader.
public struct TEFeedback: Equatable, Sendable {
    public enum Tone: Equatable, Sendable {
        case success, info, warning, failure
    }

    public var title: String
    public var detail: String?
    public var tone: Tone
    public var systemImage: String

    public init(title: String, detail: String? = nil, tone: Tone, systemImage: String? = nil) {
        self.title = title
        self.detail = detail
        self.tone = tone
        self.systemImage = systemImage ?? Self.defaultSystemImage(for: tone)
    }

    public var autoDismissDelay: Duration? {
        switch tone {
        case .success, .info: .seconds(5)
        case .warning, .failure: nil
        }
    }

    public var announcement: String {
        guard let detail else { return title }
        return "\(title). \(detail)"
    }

    private static func defaultSystemImage(for tone: Tone) -> String {
        switch tone {
        case .success: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failure: "exclamationmark.octagon.fill"
        }
    }
}

public extension TEFeedback {
    init(offlineAction feedback: CacheActionFeedback) {
        if feedback.isFailure {
            self.init(title: feedback.message, tone: .failure)
        } else {
            self.init(title: feedback.message, tone: .success, systemImage: "arrow.down.circle.fill")
        }
    }

    init(updateRefresh result: LibraryUpdateRefreshResult) {
        var detail = "\(result.checkedCount) checked, \(result.updatedCount) \(result.updatedCount == 1 ? "update" : "updates")"
        if result.failedCount > 0 {
            detail += ", \(result.failedCount) failed"
        }
        if result.failedCount == result.checkedCount, result.checkedCount > 0 {
            self.init(title: "Update check failed", detail: detail, tone: .failure)
        } else if result.failedCount > 0 {
            self.init(title: "Some updates unavailable", detail: detail, tone: .warning)
        } else if result.updatedCount > 0 {
            self.init(title: "Updates found", detail: detail, tone: .success)
        } else {
            self.init(title: "No new chapters", detail: detail, tone: .info)
        }
    }

    init(librarySaveSucceeded: Bool) {
        if librarySaveSucceeded {
            self.init(title: "Saved to Library", tone: .success, systemImage: "bookmark.fill")
        } else {
            self.init(title: "Couldn’t save this series", detail: "Try again.", tone: .failure)
        }
    }
}

public struct TEFeedbackBannerLayout: Equatable, Sendable {
    public enum Placement: Equatable, Sendable {
        case bottom
    }

    public let placement: Placement = .bottom
    public let maximumWidth: CGFloat = 560
    public let dismissHitSize: CGFloat = TEActionMetrics.minimumHitSize
    public let dismissAccessibilityLabel = "Dismiss"
    /// Transient feedback stays slim: it scales up to the first accessibility size
    /// rather than covering the content it reports on. VoiceOver reads the full text.
    public let maximumDynamicTypeSize: DynamicTypeSize = .accessibility1

    public init() {}
}

public struct TEFeedbackBanner: View {
    private let feedback: TEFeedback
    private let dismiss: () -> Void
    private let layout = TEFeedbackBannerLayout()

    public init(_ feedback: TEFeedback, dismiss: @escaping () -> Void) {
        self.feedback = feedback
        self.dismiss = dismiss
    }

    public var body: some View {
        HStack(spacing: ToonEdgeSpacing.small) {
            Image(systemName: feedback.systemImage)
                .font(ToonEdgeTypography.body)
                .foregroundStyle(toneColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(feedback.title)
                    .font(ToonEdgeTypography.body.weight(.semibold))
                    .foregroundStyle(ToonEdgeColor.textPrimary)
                if let detail = feedback.detail {
                    Text(detail)
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(ToonEdgeTypography.caption.weight(.semibold))
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .frame(width: layout.dismissHitSize, height: layout.dismissHitSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(layout.dismissAccessibilityLabel)
            .accessibilityIdentifier("feedback.dismiss")
        }
        .padding(.leading, ToonEdgeSpacing.medium)
        .padding(.vertical, ToonEdgeSpacing.xsmall)
        .frame(maxWidth: layout.maximumWidth)
        .background(ToonEdgeColor.accentSoft, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: ToonEdgeRadius.medium)
                .stroke(toneColor.opacity(0.35))
        )
        .dynamicTypeSize(...layout.maximumDynamicTypeSize)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feedback.banner")
    }

    private var toneColor: Color {
        switch feedback.tone {
        case .success: ToonEdgeColor.success
        case .info: ToonEdgeColor.accent
        case .warning: ToonEdgeColor.warning
        case .failure: ToonEdgeColor.failure
        }
    }
}

private struct TEFeedbackBannerHost: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var feedback: TEFeedback?
    let presentation: TEFeedbackBannerPresentation
    let bottomInset: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        switch presentation {
        case .reservesSpace:
            content
                .safeAreaInset(edge: .bottom, spacing: 0) { banner }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: feedback)
        case .floats:
            content
                .overlay(alignment: .bottom) { banner }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: feedback)
        }
    }

    @ViewBuilder
    private var banner: some View {
        if let feedback {
            TEFeedbackBanner(feedback) { self.feedback = nil }
                .padding(.horizontal, ToonEdgeSpacing.large)
                .padding(.top, presentation == .reservesSpace ? ToonEdgeSpacing.small : 0)
                .padding(.bottom, ToonEdgeSpacing.medium + bottomInset)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .task(id: feedback) {
                    announce(feedback)
                    guard let delay = feedback.autoDismissDelay else { return }
                    try? await Task.sleep(for: delay)
                    guard !Task.isCancelled, self.feedback == feedback else { return }
                    self.feedback = nil
                }
        }
    }

    private func announce(_ feedback: TEFeedback) {
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: feedback.announcement)
        #endif
    }
}

/// Scrolling screens reserve room so the banner never hides content; the Reader and
/// Browser float it so the page does not reflow under the reader.
public enum TEFeedbackBannerPresentation: Equatable, Sendable {
    case reservesSpace
    case floats
}

public extension View {
    /// Shows `feedback` as the shared bottom banner. `bottomInset` lifts a floating banner
    /// above screen-owned bottom controls; tab bars are already outside the safe area.
    func teFeedbackBanner(
        _ feedback: Binding<TEFeedback?>,
        presentation: TEFeedbackBannerPresentation = .reservesSpace,
        bottomInset: CGFloat = 0
    ) -> some View {
        modifier(TEFeedbackBannerHost(feedback: feedback, presentation: presentation, bottomInset: bottomInset))
    }
}
