import SwiftUI

struct ReaderChromeSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        Color.black.opacity(reduceTransparency || contrast == .increased ? 1 : 0.56)
    }
}
