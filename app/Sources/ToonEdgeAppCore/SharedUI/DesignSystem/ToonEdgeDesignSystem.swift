import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum ToonEdgeAppearance: CaseIterable, Sendable {
    case light, dark, lightIncreasedContrast, darkIncreasedContrast
}

public struct ToonEdgeAppearancePolicy: Equatable, Sendable {
    public var forcedColorScheme: ColorScheme? = nil
    public var readerCanvasIsIndependent = true
    public static let `default` = Self()
}

public struct ToonEdgeMotionPolicy: Equatable, Sendable {
    public let positionalDuration: Double

    public init(reduceMotion: Bool) {
        positionalDuration = reduceMotion ? 0 : 0.18
    }
}

/// Opaque sRGB components shared by platform colors and deterministic contrast checks.
public struct ToonEdgeColorValue: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(white: Double) {
        self.init(red: white, green: white, blue: white)
    }

    public static let black = Self(white: 0)
    public static let white = Self(white: 1)

    public var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }

    public func contrastRatio(with other: Self) -> Double {
        let lighter = max(luminance, other.luminance)
        let darker = min(luminance, other.luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private var luminance: Double {
        func linear(_ component: Double) -> Double {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

public struct ToonEdgeColorPair: Equatable, Sendable {
    public let foreground: ToonEdgeColorValue
    public let background: ToonEdgeColorValue
}

public struct ToonEdgePaletteValues: Equatable, Sendable {
    public let canvas: ToonEdgeColorValue
    public let raised: ToonEdgeColorValue
    public let panel: ToonEdgeColorValue
    public let textPrimary: ToonEdgeColorValue
    public let textSecondary: ToonEdgeColorValue
    public let accent: ToonEdgeColorValue
    public let accentSoft: ToonEdgeColorValue
    public let success: ToonEdgeColorValue
    public let warning: ToonEdgeColorValue
    public let failure: ToonEdgeColorValue
    public let border: ToonEdgeColorValue

    public var textOnCanvasContrast: Double { textPrimary.contrastRatio(with: canvas) }

    public var banner: ToonEdgeColorPair {
        .init(foreground: textPrimary, background: panel)
    }

    public var filledAction: ToonEdgeColorPair {
        .init(
            foreground: accent.contrastRatio(with: .white) >= 4.5 ? .white : .black,
            background: accent
        )
    }

    public static func resolve(_ appearance: ToonEdgeAppearance) -> Self {
        let increased = appearance == .lightIncreasedContrast || appearance == .darkIncreasedContrast
        switch appearance {
        case .light, .lightIncreasedContrast:
            return Self(
                canvas: .init(white: 0.97),
                raised: .white,
                panel: .init(white: 0.92),
                textPrimary: .init(white: increased ? 0 : 0.10),
                textSecondary: .init(white: increased ? 0.20 : 0.38),
                accent: .init(red: increased ? 0.30 : 0.40, green: 0.20, blue: 0.70),
                accentSoft: .init(red: 0.91, green: 0.87, blue: 0.98),
                success: .init(red: 0.10, green: increased ? 0.32 : 0.40, blue: 0.24),
                warning: .init(red: increased ? 0.43 : 0.51, green: 0.31, blue: 0.04),
                failure: .init(red: increased ? 0.62 : 0.72, green: 0.12, blue: 0.15),
                border: .init(white: increased ? 0.40 : 0.76)
            )
        case .dark, .darkIncreasedContrast:
            return Self(
                canvas: increased ? .black : .init(red: 0.05, green: 0.055, blue: 0.075),
                raised: .init(red: 0.09, green: 0.095, blue: 0.13),
                panel: .init(red: 0.12, green: 0.125, blue: 0.17),
                textPrimary: increased ? .white : .init(red: 0.96, green: 0.96, blue: 0.98),
                textSecondary: .init(white: increased ? 0.86 : 0.72),
                accent: .init(red: increased ? 0.77 : 0.68, green: 0.55, blue: 1),
                accentSoft: .init(red: 0.31, green: 0.23, blue: 0.49),
                success: .init(red: 0.36, green: increased ? 0.90 : 0.78, blue: 0.58),
                warning: .init(red: 1, green: increased ? 0.87 : 0.76, blue: 0.36),
                failure: .init(red: 1, green: increased ? 0.64 : 0.48, blue: 0.50),
                border: .init(white: increased ? 0.65 : 0.28)
            )
        }
    }
}

public enum ToonEdgeColor {
    public static let background = adaptive { $0.canvas }
    public static let elevated = adaptive { $0.raised }
    public static let panel = adaptive { $0.panel }
    public static let textPrimary = adaptive { $0.textPrimary }
    public static let textSecondary = adaptive { $0.textSecondary }
    public static let accent = adaptive { $0.accent }
    public static let accentSoft = adaptive { $0.accentSoft }
    public static let filledActionForeground = adaptive { $0.filledAction.foreground }
    public static let filledActionBackground = adaptive { $0.filledAction.background }
    public static let bannerForeground = adaptive { $0.banner.foreground }
    public static let bannerBackground = adaptive { $0.banner.background }
    public static let success = adaptive { $0.success }
    public static let warning = adaptive { $0.warning }
    public static let failure = adaptive { $0.failure }
    public static let border = adaptive { $0.border }

    private static func adaptive(_ value: @escaping @Sendable (ToonEdgePaletteValues) -> ToonEdgeColorValue) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            let appearance: ToonEdgeAppearance
            switch (traits.userInterfaceStyle == .dark, traits.accessibilityContrast == .high) {
            case (false, false): appearance = .light
            case (false, true): appearance = .lightIncreasedContrast
            case (true, false): appearance = .dark
            case (true, true): appearance = .darkIncreasedContrast
            }
            let components = value(.resolve(appearance))
            return UIColor(red: components.red, green: components.green, blue: components.blue, alpha: 1)
        })
        #elseif canImport(AppKit)
        Color(nsColor: NSColor(name: nil) { appearance in
            let resolved: ToonEdgeAppearance
            switch appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua]) {
            case .darkAqua: resolved = .dark
            case .accessibilityHighContrastAqua: resolved = .lightIncreasedContrast
            case .accessibilityHighContrastDarkAqua: resolved = .darkIncreasedContrast
            default: resolved = .light
            }
            let components = value(.resolve(resolved))
            return NSColor(srgbRed: components.red, green: components.green, blue: components.blue, alpha: 1)
        })
        #else
        value(.resolve(.light)).color
        #endif
    }
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
            .toolbarBackground(ToonEdgeColor.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
