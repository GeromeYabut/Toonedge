import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
                .background(ToonEdgeColor.accent, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
                .foregroundStyle(.white)
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
                .background(ToonEdgeColor.accent, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
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
        .background(ToonEdgeColor.panel, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
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

public struct CachedCoverArtwork<Placeholder: View>: View {
    private let url: URL?
    private let cache: CoverArtworkMemoryCache
    private let placeholder: Placeholder
    @State private var imageData: Data?

    public init(
        url: URL?,
        cache: CoverArtworkMemoryCache = .shared,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.cache = cache
        self.placeholder = placeholder()
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
