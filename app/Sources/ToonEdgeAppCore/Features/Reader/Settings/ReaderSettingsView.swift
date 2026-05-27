import SwiftUI

public struct ReaderSettingsView: View {
    @ObservedObject private var viewModel: ReaderViewModel

    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
                TESegmentedControl(selection: displayModeBinding) { mode in
                    mode.title
                }

                Toggle("Page Spacing", isOn: pageSpacingBinding)
                    .font(ToonEdgeTypography.body)

                VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                    Text("Brightness Aid")
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                    Slider(value: brightnessBinding, in: 0...0.75)
                        .tint(ToonEdgeColor.accent)
                }

                VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                    Text("Canvas")
                        .font(ToonEdgeTypography.caption)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                    HStack(spacing: ToonEdgeSpacing.small) {
                        canvasButton(.charcoal)
                        canvasButton(.black)
                        canvasButton(.paper)
                    }
                }

                Spacer()
            }
            .padding(ToonEdgeSpacing.large)
            .navigationTitle("Reader Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
        Button {
            viewModel.setCanvas(canvas)
        } label: {
            HStack(spacing: ToonEdgeSpacing.small) {
                Circle()
                    .fill(swatch(for: canvas))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(ToonEdgeColor.border))
                Text(canvas.title)
                    .font(ToonEdgeTypography.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ToonEdgeSpacing.medium)
            .background(
                viewModel.settings.readerCanvas == canvas ? ToonEdgeColor.accentSoft : ToonEdgeColor.panel,
                in: RoundedRectangle(cornerRadius: ToonEdgeRadius.small)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ToonEdgeRadius.small)
                    .stroke(ToonEdgeColor.border)
            )
        }
        .buttonStyle(.plain)
    }

    private func swatch(for canvas: ReaderCanvas) -> Color {
        switch canvas {
        case .charcoal:
            ToonEdgeColor.background
        case .black:
            .black
        case .paper:
            Color(red: 0.89, green: 0.86, blue: 0.78)
        }
    }
}
