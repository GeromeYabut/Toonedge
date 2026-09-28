import SwiftUI

struct ReaderCanvasPaletteValues: Equatable, Sendable {
    let background: ToonEdgeColorValue
    let foreground: ToonEdgeColorValue

    var textContrast: Double { foreground.contrastRatio(with: background) }
}

/// Reader colors depend only on the saved canvas, never on application appearance.
enum ReaderCanvasPalette {
    static func values(for canvas: ReaderCanvas) -> ReaderCanvasPaletteValues {
        switch canvas {
        case .charcoal:
            .init(background: .init(red: 0.05, green: 0.055, blue: 0.075), foreground: .white)
        case .black:
            .init(background: .black, foreground: .white)
        case .paper:
            .init(background: .init(red: 0.89, green: 0.86, blue: 0.78), foreground: .init(white: 0.10))
        }
    }
}
