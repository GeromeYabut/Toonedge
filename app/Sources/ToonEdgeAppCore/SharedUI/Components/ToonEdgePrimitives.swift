import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum TEEditorialGroupStyle: Equatable, Sendable {
    case plain, elevated

    public static let `default`: Self = .plain
    public var drawsBorder: Bool { false }
    public var usesElevation: Bool { self == .elevated }
}

/// A borderless group of identified rows. A nil inset omits separators;
/// a non-nil inset draws separators between rows, never after the last row.
public struct TEEditorialGroup<Rows: RandomAccessCollection, Row: View>: View where Rows.Element: Identifiable {
    private let rows: Rows
    private let spacing: CGFloat
    private let separatorInset: CGFloat?
    private let style: TEEditorialGroupStyle
    private let row: (Rows.Element) -> Row

    public init(
        _ rows: Rows,
        spacing: CGFloat = ToonEdgeSpacing.small,
        separatorInset: CGFloat? = nil,
        style: TEEditorialGroupStyle = .default,
        @ViewBuilder row: @escaping (Rows.Element) -> Row
    ) {
        self.rows = rows
        self.spacing = spacing
        self.separatorInset = separatorInset
        self.style = style
        self.row = row
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(rows) { item in
                row(item)
                if let separatorInset, item.id != rows.last?.id {
                    Rectangle()
                        .fill(ToonEdgeColor.border)
                        .frame(height: 1)
                        .padding(.leading, max(0, separatorInset))
                        .accessibilityHidden(true)
                }
            }
        }
        .background(
            style.usesElevation ? ToonEdgeColor.elevated : Color.clear,
            in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium)
        )
    }
}

public enum TEActionMetrics {
    public static let minimumHitSize: CGFloat = 44
}

/// Selection is conveyed by both a quiet surface and an accessibility trait.
public struct TEEditorialRowStyle: ViewModifier {
    private let isSelected: Bool

    public init(isSelected: Bool = false) {
        self.isSelected = isSelected
    }

    public func body(content: Content) -> some View {
        content
            .font(ToonEdgeTypography.body)
            .foregroundStyle(ToonEdgeColor.textPrimary)
            .padding(.horizontal, ToonEdgeSpacing.medium)
            .padding(.vertical, ToonEdgeSpacing.small)
            .frame(minWidth: TEActionMetrics.minimumHitSize, maxWidth: .infinity,
                   minHeight: TEActionMetrics.minimumHitSize, alignment: .leading)
            .background(isSelected ? ToonEdgeColor.panel : Color.clear,
                        in: RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
            .contentShape(Rectangle())
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

public struct TEActionFeedback: Equatable, Sendable {
    public let opacity: Double
    public let scale: CGFloat

    public init(isPressed: Bool, isEnabled: Bool, reduceMotion: Bool) {
        opacity = !isEnabled ? 0.45 : (isPressed ? 0.75 : 1)
        scale = isEnabled && isPressed && !reduceMotion ? 0.98 : 1
    }
}

public struct TEActionStyle: ButtonStyle {
    public enum Surface: Equatable, Sendable {
        case plain, filled, elevated
    }

    private let surface: Surface

    public init(surface: Surface = .plain) {
        self.surface = surface
    }

    public func makeBody(configuration: Configuration) -> some View {
        TEActionLabel(surface: surface, isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}

/// Shared by the real ButtonStyle and the deterministic pressed-state preview.
private struct TEActionLabel<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let surface: TEActionStyle.Surface
    let isPressed: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        let feedback = TEActionFeedback(isPressed: isPressed, isEnabled: isEnabled, reduceMotion: reduceMotion)
        label()
            .font(ToonEdgeTypography.body.weight(.semibold))
            .padding(.horizontal, ToonEdgeSpacing.medium)
            .padding(.vertical, ToonEdgeSpacing.small)
            .frame(minWidth: TEActionMetrics.minimumHitSize, minHeight: TEActionMetrics.minimumHitSize)
            .foregroundStyle(surface == .filled ? ToonEdgeColor.filledActionForeground : ToonEdgeColor.textPrimary)
            .background(background, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
            .opacity(feedback.opacity)
            .scaleEffect(feedback.scale)
            .animation(reduceMotion ? nil : .easeOut(duration: ToonEdgeMotionPolicy(reduceMotion: false).positionalDuration), value: isPressed)
            // Keep the hit region unscaled even while the visual label is pressed.
            .frame(minWidth: TEActionMetrics.minimumHitSize, minHeight: TEActionMetrics.minimumHitSize)
            .contentShape(Rectangle())
    }

    private var background: Color {
        switch surface {
        case .plain: .clear
        case .filled: ToonEdgeColor.filledActionBackground
        case .elevated: ToonEdgeColor.elevated
        }
    }
}

/// No feature routing or state: this host exercises the same views used by clients.
struct TEEditorialPrimitiveGallery: View {
    private enum Sample: String, CaseIterable, Identifiable {
        case plain = "Plain row", selected = "Selected row"
        var id: Self { self }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
            Text("Editorial primitives").font(ToonEdgeTypography.title)
            TEEditorialGroup(Sample.allCases, separatorInset: ToonEdgeSpacing.medium) { sample in
                HStack {
                    Text(sample.rawValue)
                    if sample == .selected {
                        Spacer()
                        Image(systemName: "checkmark").accessibilityHidden(true)
                    }
                }
                .modifier(TEEditorialRowStyle(isSelected: sample == .selected))
            }
            TEEditorialGroup([Sample.plain], style: .elevated) { _ in
                Text("Elevated group").modifier(TEEditorialRowStyle())
            }
            Button("Plain action") {}.buttonStyle(TEActionStyle())
            Button("Filled action") {}.buttonStyle(TEActionStyle(surface: .filled))
            Button("Elevated action") {}.buttonStyle(TEActionStyle(surface: .elevated))
            Button("Disabled action") {}.buttonStyle(TEActionStyle()).disabled(true)
            Button("Pressed action") {}.buttonStyle(TEPressedPreviewStyle())
        }
        .padding(ToonEdgeSpacing.large)
        .foregroundStyle(ToonEdgeColor.textPrimary)
        .background(ToonEdgeColor.background)
    }
}

private struct TEPressedPreviewStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TEActionLabel(surface: .filled, isPressed: true) { configuration.label }
    }
}

private struct TEEditorialPrimitivePreviews: PreviewProvider {
    static var previews: some View {
        ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
            TEEditorialPrimitiveGallery()
                .environment(\.colorScheme, scheme)
                .previewLayout(.fixed(width: 360, height: 680))
                .previewDisplayName("\(scheme)")
        }
    }
}

public struct TEButton: View {
    private let title: String
    private let systemImage: String?
    private let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "circle.fill")
                .labelStyle(.titleAndIcon)
                .font(ToonEdgeTypography.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, ToonEdgeSpacing.medium)
                .background(ToonEdgeColor.filledActionBackground, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
                .foregroundStyle(ToonEdgeColor.filledActionForeground)
        }
        .buttonStyle(.plain)
    }
}

public struct TEChip: View {
    private let title: String
    private let isActive: Bool

    public init(_ title: String, isActive: Bool = false) {
        self.title = title
        self.isActive = isActive
    }

    public var body: some View {
        Text(title)
            .font(ToonEdgeTypography.caption)
            .padding(.horizontal, ToonEdgeSpacing.medium)
            .padding(.vertical, ToonEdgeSpacing.small)
            .background(isActive ? ToonEdgeColor.accentSoft : ToonEdgeColor.panel)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(ToonEdgeColor.border))
    }
}

public struct TECard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(ToonEdgeSpacing.large)
            .background(ToonEdgeColor.elevated, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: ToonEdgeRadius.medium)
                    .stroke(ToonEdgeColor.border)
            )
    }
}

public struct AddToLibraryStatePickerView: View {
    private let title: String
    @Binding private var selectedState: LibraryCollectionState
    private let context: LibraryAddContext
    private let confirm: (LibraryCollectionState) -> Void
    private let cancel: () -> Void

    public init(
        title: String,
        selectedState: Binding<LibraryCollectionState>,
        context: LibraryAddContext,
        confirm: @escaping (LibraryCollectionState) -> Void,
        cancel: @escaping () -> Void
    ) {
        self.title = title
        self._selectedState = selectedState
        self.context = context
        self.confirm = confirm
        self.cancel = cancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text("Save to Library")
                    .font(ToonEdgeTypography.title)
                Text(title)
                    .font(ToonEdgeTypography.body)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .lineLimit(2)
            }

            VStack(spacing: ToonEdgeSpacing.small) {
                ForEach(AddToLibraryStatePickerModel.availableStates, id: \.self) { state in
                    Button {
                        selectedState = state
                    } label: {
                        HStack(spacing: ToonEdgeSpacing.medium) {
                            Image(systemName: selectedState == state ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedState == state ? ToonEdgeColor.accent : ToonEdgeColor.textSecondary)
                            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                                Text(state.title)
                                    .font(ToonEdgeTypography.body.weight(.semibold))
                                Text(subtitle(for: state))
                                    .font(ToonEdgeTypography.caption)
                                    .foregroundStyle(ToonEdgeColor.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(ToonEdgeSpacing.medium)
                        .background(
                            selectedState == state ? ToonEdgeColor.panel : ToonEdgeColor.elevated,
                            in: RoundedRectangle(cornerRadius: ToonEdgeRadius.small)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: ToonEdgeSpacing.medium) {
                Button("Cancel", action: cancel)
                    .font(ToonEdgeTypography.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ToonEdgeSpacing.medium)
                    .background(ToonEdgeColor.panel, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.small))

                Button("Save") {
                    confirm(selectedState)
                }
                .font(ToonEdgeTypography.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, ToonEdgeSpacing.medium)
                .background(ToonEdgeColor.filledActionBackground, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
                .foregroundStyle(ToonEdgeColor.filledActionForeground)
            }
            .buttonStyle(.plain)
        }
        .padding(ToonEdgeSpacing.xlarge)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(ToonEdgeColor.background)
        .foregroundStyle(ToonEdgeColor.textPrimary)
    }

    private func subtitle(for state: LibraryCollectionState) -> String {
        switch state {
        case .reading:
            return context == .reader ? "Resume from your current chapter" : "Actively reading"
        case .planned:
            return "Saved for later"
        case .dropped, .archived:
            return "Paused or no longer following"
        case .completed:
            return "Finished title"
        }
    }
}

public struct TEBanner: View {
    private let title: String
    private let message: String
    private let systemImage: String

    public init(title: String, message: String, systemImage: String = "sparkles") {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(ToonEdgeColor.accent)
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text(title)
                    .font(ToonEdgeTypography.sectionTitle)
                Text(message)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
            }
            Spacer()
        }
        .padding(ToonEdgeSpacing.large)
        .foregroundStyle(ToonEdgeColor.bannerForeground)
        .background(ToonEdgeColor.bannerBackground, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
    }
}

public struct TEListRow: View {
    private let title: String
    private let subtitle: String
    private let systemImage: String

    public init(title: String, subtitle: String, systemImage: String = "book.pages") {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            Image(systemName: systemImage)
                .frame(width: 28, height: 28)
                .foregroundStyle(ToonEdgeColor.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text(title)
                    .font(ToonEdgeTypography.body.weight(.semibold))
                Text(subtitle)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, ToonEdgeSpacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
    }
}

public struct TESegmentedControl<Selection: Hashable & CaseIterable & Identifiable>: View where Selection.AllCases: RandomAccessCollection, Selection.ID == Selection {
    @Binding private var selection: Selection
    private let title: (Selection) -> String

    public init(selection: Binding<Selection>, title: @escaping (Selection) -> String) {
        self._selection = selection
        self.title = title
    }

    public var body: some View {
        HStack(spacing: ToonEdgeSpacing.small) {
            ForEach(Array(Selection.allCases)) { item in
                Button {
                    selection = item
                } label: {
                    Text(title(item))
                        .font(ToonEdgeTypography.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ToonEdgeSpacing.small)
                        .background(
                            selection == item ? ToonEdgeColor.accentSoft : Color.clear,
                            in: RoundedRectangle(cornerRadius: ToonEdgeRadius.small)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ToonEdgeSpacing.xsmall)
        .background(ToonEdgeColor.panel, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
    }
}

@MainActor
public final class CoverArtworkMemoryCache {
    public static let shared = CoverArtworkMemoryCache()

    private var storage: [URL: Data] = [:]

    public init() {}

    public func data(for url: URL) -> Data? {
        storage[url]
    }

    public func store(_ data: Data, for url: URL) {
        storage[url] = data
    }
}

@MainActor
public struct CoverArtworkStartupPolicy: Equatable, Sendable {
    public init() {}

    public static func initialData(url: URL?, cache: CoverArtworkMemoryCache) -> Data? {
        guard let url else {
            return nil
        }

        return cache.data(for: url)
    }
}

public struct CachedCoverArtwork<Placeholder: View>: View {
    private let url: URL?
    private let cache: CoverArtworkMemoryCache
    private let placeholder: Placeholder
    @State private var imageData: Data?

    @MainActor
    public init(
        url: URL?,
        cache: CoverArtworkMemoryCache = .shared,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.cache = cache
        self.placeholder = placeholder()
        self._imageData = State(initialValue: CoverArtworkStartupPolicy.initialData(url: url, cache: cache))
    }

    public var body: some View {
        Group {
            if let imageData, let image = platformImage(from: imageData) {
                platformImageView(image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: url) {
            await loadIfNeeded()
        }
    }

    @MainActor
    private func loadIfNeeded() async {
        guard let url else {
            imageData = nil
            return
        }

        if let cached = cache.data(for: url) {
            imageData = cached
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            cache.store(data, for: url)
            imageData = data
        } catch {
            imageData = nil
        }
    }

    private func platformImage(from data: Data) -> PlatformCoverImage? {
        #if canImport(UIKit)
        UIImage(data: data)
        #elseif canImport(AppKit)
        NSImage(data: data)
        #else
        nil
        #endif
    }

    private func platformImageView(_ image: PlatformCoverImage) -> Image {
        #if canImport(UIKit)
        Image(uiImage: image)
        #elseif canImport(AppKit)
        Image(nsImage: image)
        #endif
    }
}

#if canImport(UIKit)
private typealias PlatformCoverImage = UIImage
#elseif canImport(AppKit)
private typealias PlatformCoverImage = NSImage
#endif
