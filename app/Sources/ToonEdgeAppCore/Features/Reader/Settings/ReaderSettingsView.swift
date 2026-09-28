import SwiftUI

public struct ReaderSettingsView: View {
    @ObservedObject private var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let layout = ReaderSettingsLayout(dynamicTypeIsAccessibility: dynamicTypeSize.isAccessibilitySize)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
                    Picker("Image Fit", selection: displayModeBinding) {
                        ForEach(ReaderDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("reader-settings.fit")

                    Toggle("Page Spacing", isOn: pageSpacingBinding)
                        .font(ToonEdgeTypography.body)
                        .frame(minHeight: layout.minimumActionSize)
                        .accessibilityIdentifier("reader-settings.pageSpacing")

                    VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                        Text("Brightness Aid")
                            .font(ToonEdgeTypography.caption)
                            .foregroundStyle(ToonEdgeColor.textSecondary)
                        Slider(value: brightnessBinding, in: 0...0.75)
                            .tint(ToonEdgeColor.accent)
                            .accessibilityLabel("Brightness Aid")
                            .accessibilityValue("\(Int((viewModel.settings.brightnessAid * 100).rounded())) percent")
                            .accessibilityIdentifier("reader-settings.brightness")
                    }

                    VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                        Text("Canvas")
                            .font(ToonEdgeTypography.caption)
                            .foregroundStyle(ToonEdgeColor.textSecondary)

                        VStack(spacing: 0) {
                            ForEach(Array([ReaderCanvas.charcoal, .black, .paper].enumerated()), id: \.element.rawValue) { index, canvas in
                                canvasButton(canvas)
                                if index < 2 {
                                    Divider()
                                        .padding(.leading, ToonEdgeSpacing.xlarge)
                                }
                            }
                        }
                    }
                }
                .padding(ToonEdgeSpacing.large)
            }
            .accessibilityIdentifier("reader-settings.scroll")
            .navigationTitle("Reader Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if layout.showsDoneAction {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                        .accessibilityIdentifier("reader-settings.done")
                    }
                }
            }
            .toonEdgeScreen()
        }
    }

    private var displayModeBinding: Binding<ReaderDisplayMode> {
        Binding(
            get: { viewModel.settings.displayMode },
            set: { viewModel.setDisplayMode($0) }
        )
    }

    private var pageSpacingBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.isPageSpacingEnabled },
            set: { viewModel.setPageSpacingEnabled($0) }
        )
    }

    private var brightnessBinding: Binding<Double> {
        Binding(
            get: { viewModel.settings.brightnessAid },
            set: { viewModel.setBrightnessAid($0) }
        )
    }

    private func canvasButton(_ canvas: ReaderCanvas) -> some View {
        let presentation = ReaderCanvasRowPresentation(
            canvas: canvas,
            selectedCanvas: viewModel.settings.readerCanvas
        )
        return Button {
            viewModel.setCanvas(canvas)
        } label: {
            HStack(spacing: ToonEdgeSpacing.small) {
                Circle()
                    .fill(Self.swatch(for: canvas))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(ToonEdgeColor.border))
                Text(canvas.title)
                    .font(ToonEdgeTypography.body)
                Spacer()
                if presentation.showsCheckmark {
                    Image(systemName: "checkmark")
                        .foregroundStyle(ToonEdgeColor.accent)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: presentation.minimumActionSize, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(canvas.title) Canvas")
        .accessibilityValue(presentation.accessibilityValue)
        .accessibilityAddTraits(presentation.showsCheckmark ? .isSelected : [])
        .accessibilityIdentifier("reader-settings.canvas.\(canvas.rawValue)")
    }

    static func swatch(for canvas: ReaderCanvas) -> Color {
        ReaderCanvasPalette.values(for: canvas).background.color
    }
}

struct ReaderSettingsLayout: Equatable, Sendable {
    var usesScrollingContent: Bool
    var supportsMediumDetent: Bool
    var supportsLargeDetent: Bool
    var showsDoneAction: Bool
    var minimumActionSize: CGFloat

    init(dynamicTypeIsAccessibility: Bool) {
        self.usesScrollingContent = true
        self.supportsMediumDetent = true
        self.supportsLargeDetent = true
        self.showsDoneAction = true
        self.minimumActionSize = 44
    }
}

struct ReaderCanvasRowPresentation: Equatable, Sendable {
    var usesBorder: Bool { false }
    var showsCheckmark: Bool
    var minimumActionSize: CGFloat { 44 }
    var accessibilityValue: String { showsCheckmark ? "Selected" : "Not selected" }

    init(canvas: ReaderCanvas, selectedCanvas: ReaderCanvas) {
        self.showsCheckmark = canvas == selectedCanvas
    }
}
