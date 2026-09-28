import Testing
@testable import ToonEdgeAppCore

@Test func applicationAppearanceFollowsTheSystem() {
    #expect(ToonEdgeAppearancePolicy.default.forcedColorScheme == nil)
    #expect(ToonEdgeAppearancePolicy.default.readerCanvasIsIndependent)
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
