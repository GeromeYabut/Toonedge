import Testing
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
@testable import ToonEdgeAppCore

@Test func applicationAppearanceFollowsTheSystem() {
    #expect(ToonEdgeAppearancePolicy.default.forcedColorScheme == nil)
    #expect(ToonEdgeAppearancePolicy.default.readerCanvasIsIndependent)
}

@Test func editorialTypographyUsesSystemDesignAndRestrainedWeights() {
    #expect(ToonEdgeTypographyMetrics.title.textStyle == .title2)
    #expect(ToonEdgeTypographyMetrics.sectionTitle.textStyle == .headline)
    #expect(ToonEdgeTypographyMetrics.title.weight == .bold)
    #expect(ToonEdgeTypographyMetrics.sectionTitle.weight == .semibold)
    #expect(ToonEdgeTypographyMetrics.body.design == .default)
    #expect(ToonEdgeTypographyMetrics.caption.design == .default)
    #expect(ToonEdgeTypographyMetrics.body.weight == .regular)
    #expect(ToonEdgeTypographyMetrics.caption.weight == .regular)
    #expect(ToonEdgeTypographyMetrics.numericMetadata.usesMonospacedDigits)
}

@Test func adaptivePalettesMaintainAbsoluteTextContrast() {
    for appearance in ToonEdgeAppearance.allCases {
        let palette = ToonEdgePaletteValues.resolve(appearance)
        #expect(palette.textOnCanvasContrast >= 4.5)
        #expect(palette.canvas != palette.raised)
        for surface in [palette.canvas, palette.raised, palette.panel] {
            #expect(palette.textPrimary.contrastRatio(with: surface) >= 4.5)
            #expect(palette.textSecondary.contrastRatio(with: surface) >= 4.5)
        }
    }
    let contrastPairs: [(ToonEdgeAppearance, ToonEdgeAppearance)] = [
        (.light, .lightIncreasedContrast), (.dark, .darkIncreasedContrast)
    ]
    for (standard, increased) in contrastPairs {
        let standardPalette = ToonEdgePaletteValues.resolve(standard)
        let increasedPalette = ToonEdgePaletteValues.resolve(increased)
        #expect(increasedPalette.textOnCanvasContrast > standardPalette.textOnCanvasContrast)
        #expect(increasedPalette.border.contrastRatio(with: increasedPalette.canvas) > standardPalette.border.contrastRatio(with: standardPalette.canvas))
    }
}

@Test func reduceMotionUsesNoPositionalDuration() {
    #expect(ToonEdgeMotionPolicy(reduceMotion: true).positionalDuration == 0)
    #expect(ToonEdgeMotionPolicy(reduceMotion: false).positionalDuration == 0.18)
}

@Test func bannerOwnsAnAdaptiveForegroundAndBackground() {
    for appearance in ToonEdgeAppearance.allCases {
        let palette = ToonEdgePaletteValues.resolve(appearance)
        // A banner must not inherit the fixed Reader canvas foreground.
        #expect(palette.banner.foreground == palette.textPrimary)
        #expect(palette.banner.background == palette.panel)
        #expect(palette.banner.foreground.contrastRatio(with: palette.banner.background) >= 4.5)
        #expect(palette.textSecondary.contrastRatio(with: palette.banner.background) >= 4.5)
    }
}

@Test func filledActionsMaintainTextContrastInEveryAppearance() {
    for appearance in ToonEdgeAppearance.allCases {
        let pair = ToonEdgePaletteValues.resolve(appearance).filledAction
        #expect(pair.foreground.contrastRatio(with: pair.background) >= 4.5)
    }
}

@Test func editorialGroupDefaultsToNoBorder() {
    #expect(TEEditorialGroupStyle.default.drawsBorder == false)
    #expect(TEEditorialGroupStyle.default.usesElevation == false)
    #expect(TEEditorialGroupStyle.elevated.usesElevation)
    #expect(TEEditorialGroupStyle.elevated.drawsBorder == false)
}

@Test func customActionsKeepMinimumHitRegion() {
    #expect(TEActionMetrics.minimumHitSize == 44)
}

@Test func actionFeedbackRemovesScaleUnderReduceMotion() {
    let regular = TEActionFeedback(isPressed: true, isEnabled: true, reduceMotion: false)
    let reduced = TEActionFeedback(isPressed: true, isEnabled: true, reduceMotion: true)
    #expect(regular.scale < 1)
    #expect(reduced.scale == 1)
    #expect(reduced.opacity == regular.opacity)
    #expect(reduced.opacity < 1)
}

@Test func disabledActionsIgnorePressFeedback() {
    let idle = TEActionFeedback(isPressed: false, isEnabled: true, reduceMotion: false)
    #expect(idle.scale == 1)
    #expect(idle.opacity == 1)
    let disabled = TEActionFeedback(isPressed: false, isEnabled: false, reduceMotion: false)
    #expect(disabled.scale == 1)
    #expect(disabled.opacity < 1)
    #expect(disabled == TEActionFeedback(isPressed: true, isEnabled: false, reduceMotion: false))
}

@MainActor @Test func actionStyleRendersAMinimumHitRegion() throws {
    let renderer = ImageRenderer(content:
        Button {} label: { Color.clear.frame(width: 1, height: 1) }
            .buttonStyle(TEActionStyle())
    )
    let image = try #require(renderer.cgImage)
    #expect(image.width >= 44)
    #expect(image.height >= 44)
}

#if canImport(AppKit)
@MainActor @Test func editorialPrimitiveGalleryRendersInAdaptiveStates() throws {
    // Contrast is read-only in SwiftUI; supply the real platform appearance.
    let appearances: [NSAppearance.Name] = [
        .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua
    ]
    for appearance in appearances {
        let host = NSHostingView(rootView: TEEditorialPrimitiveGallery().frame(width: 320))
        host.appearance = NSAppearance(named: appearance)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        #expect(host.bounds.width == 320)
        #expect(host.bounds.height > 300)
        #expect(bitmap.pixelsWide >= 320)
    }
}
#endif
