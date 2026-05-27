import SwiftUI

public enum ToonEdgeColor {
    public static let background = Color(red: 0.05, green: 0.055, blue: 0.075)
    public static let elevated = Color(red: 0.09, green: 0.095, blue: 0.13)
    public static let panel = Color(red: 0.12, green: 0.125, blue: 0.17)
    public static let textPrimary = Color(red: 0.96, green: 0.96, blue: 0.98)
    public static let textSecondary = Color(red: 0.68, green: 0.70, blue: 0.76)
    public static let accent = Color(red: 0.58, green: 0.42, blue: 0.95)
    public static let accentSoft = Color(red: 0.31, green: 0.23, blue: 0.49)
    public static let success = Color(red: 0.36, green: 0.78, blue: 0.58)
    public static let border = Color.white.opacity(0.12)
}

public enum ToonEdgeSpacing {
    public static let xsmall: CGFloat = 4
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
    public static let xlarge: CGFloat = 24
    public static let xxlarge: CGFloat = 32
}

public enum ToonEdgeRadius {
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 18
}

public enum ToonEdgeTypography {
    public static let title = Font.system(.title2, design: .rounded, weight: .bold)
    public static let sectionTitle = Font.system(.headline, design: .rounded, weight: .semibold)
    public static let body = Font.system(.body, design: .rounded)
    public static let caption = Font.system(.caption, design: .rounded, weight: .medium)
}

public struct ToonEdgeNavigationChrome: Equatable, Sendable {
    public enum Scheme: Equatable, Sendable {
        case dark
    }

    public var colorScheme: Scheme
    public var prefersVisibleLargeTitles: Bool

    public init(colorScheme: Scheme, prefersVisibleLargeTitles: Bool) {
        self.colorScheme = colorScheme
        self.prefersVisibleLargeTitles = prefersVisibleLargeTitles
    }

    public static let dark = ToonEdgeNavigationChrome(
        colorScheme: .dark,
        prefersVisibleLargeTitles: true
    )
}

public struct ToonEdgeScreenBackground: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        #if os(iOS)
        content
            .background(ToonEdgeColor.background.ignoresSafeArea())
            .foregroundStyle(ToonEdgeColor.textPrimary)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(ToonEdgeColor.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
        #else
        content
            .background(ToonEdgeColor.background.ignoresSafeArea())
            .foregroundStyle(ToonEdgeColor.textPrimary)
        #endif
    }
}

public extension View {
    func toonEdgeScreen() -> some View {
        modifier(ToonEdgeScreenBackground())
    }

    @ViewBuilder
    func toonEdgeFullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }
}
