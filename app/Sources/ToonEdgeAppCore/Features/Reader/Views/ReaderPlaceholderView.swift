import SwiftUI

public struct ReaderPlaceholderView: View {
    private let session: MockReaderSession
    @Binding private var router: AppRouter

    public init(session: MockReaderSession, router: Binding<AppRouter>) {
        self.session = session
        self._router = router
    }

    public var body: some View {
        VStack(spacing: ToonEdgeSpacing.large) {
            HStack {
                Button {
                    router.dismissReader()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Text(session.chapterTitle)
                    .font(ToonEdgeTypography.sectionTitle)
                Spacer()
                Button {
                    router.viewOriginalPage()
                } label: {
                    Image(systemName: "safari")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("View Original Page")
            }

            ScrollView {
                VStack(spacing: ToonEdgeSpacing.large) {
                    ForEach(Array(session.imageURLs.enumerated()), id: \.offset) { index, _ in
                        RoundedRectangle(cornerRadius: ToonEdgeRadius.small)
                            .fill(ToonEdgeColor.panel)
                            .frame(height: 360)
                            .overlay {
                                Text("Mock reader image \(index + 1)")
                                    .font(ToonEdgeTypography.caption)
                                    .foregroundStyle(ToonEdgeColor.textSecondary)
                            }
                    }
                }
            }
        }
        .padding(ToonEdgeSpacing.large)
        .toonEdgeScreen()
    }
}
