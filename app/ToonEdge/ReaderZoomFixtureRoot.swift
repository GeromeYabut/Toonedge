#if DEBUG
import SwiftUI
import UIKit

struct ReaderZoomFixtureRoot: View {
    @State private var sessionID = UUID()
    @State private var pageCount = 80
    @State private var snapshot = "{}"
    @State private var chromeVisible = true
    @State private var showOriginal = false
    @State private var request: ReaderZoomFixtureUIRequest?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack {
                    Text("Synthetic reader").font(.headline)
                    Spacer()
                    Button("New session") {
                        sessionID = UUID()
                        pageCount = pageCount == 80 ? 3 : 80
                        request = nil
                        snapshot = "{}"
                        chromeVisible = true
                    }
                    .accessibilityIdentifier("zoom.fixture.replace")
                    .frame(minHeight: 44)
                }
                HStack {
                    positionButton("First", .first, "zoom.fixture.first")
                    positionButton("Middle", .middle, "zoom.fixture.middle")
                    positionButton("Last", .last, "zoom.fixture.last")
                }
            }
            .padding(.horizontal)
            .opacity(chromeVisible ? 1 : 0)
            .allowsHitTesting(chromeVisible)
            .accessibilityHidden(!chromeVisible)

            ReaderZoomFixtureHost(sessionID: sessionID, pageCount: pageCount,
                request: request, onSnapshot: { incoming, text in
                    guard incoming == sessionID else { return }
                    snapshot = text
                }, onSingleTap: { chromeVisible.toggle() })
                .id(sessionID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("Synthetic zoom diagnostic status")
                .font(.caption2)
                .frame(height: 24)
                .accessibilityIdentifier("zoom.fixture.status")
                .accessibilityLabel("Synthetic zoom diagnostic status")
                .accessibilityValue(snapshot)

            VStack(spacing: 4) {
                HStack {
                    actionButton("Reset Zoom", .reset, "zoom.fixture.reset")
                    actionButton("Enlarge", .enlarge, "zoom.fixture.enlarge")
                    actionButton("Shrink", .shrink, "zoom.fixture.shrink")
                }
                Button("View Original Page") { showOriginal = true }
                    .accessibilityIdentifier("zoom.fixture.original")
                    .frame(minHeight: 44)
            }
            .padding(.horizontal)
            .padding(.bottom, 4)
            .opacity(chromeVisible ? 1 : 0)
            .allowsHitTesting(chromeVisible)
            .accessibilityHidden(!chromeVisible)
        }
        .background(Color.black)
        .foregroundStyle(.white)
        .buttonStyle(.bordered)
        .sheet(isPresented: $showOriginal) {
            VStack(spacing: 20) {
                Text("Owned synthetic original page")
                    .accessibilityIdentifier("zoom.fixture.originalPage")
                Text("This fixture does not make network requests.")
                Button("Return to reader") { showOriginal = false }
                    .accessibilityIdentifier("zoom.fixture.return")
                    .frame(minHeight: 44)
            }
            .padding()
        }
    }

    private func actionButton(_ title: String, _ command: ReaderZoomFixtureCommand,
                              _ identifier: String) -> some View {
        Button(title) { request = ReaderZoomFixtureUIRequest(command: command) }
            .accessibilityIdentifier(identifier)
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func positionButton(_ title: String, _ command: ReaderZoomFixtureCommand,
                                _ identifier: String) -> some View {
        actionButton(title, command, identifier)
    }
}

private struct ReaderZoomFixtureUIRequest {
    let id = UUID()
    let command: ReaderZoomFixtureCommand
}

private struct ReaderZoomFixtureHost: UIViewControllerRepresentable {
    let sessionID: UUID
    let pageCount: Int
    let request: ReaderZoomFixtureUIRequest?
    let onSnapshot: (UUID, String) -> Void
    let onSingleTap: () -> Void

    final class Coordinator {
        var lastRequestID: UUID?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> ReaderZoomFixtureViewController {
        let controller = ReaderZoomFixtureViewController(sessionID: sessionID, pageCount: pageCount)
        installCallbacks(controller)
        return controller
    }

    func updateUIViewController(_ controller: ReaderZoomFixtureViewController, context: Context) {
        installCallbacks(controller)
        guard let request, request.id != context.coordinator.lastRequestID else { return }
        context.coordinator.lastRequestID = request.id
        controller.perform(request.command)
    }

    private func installCallbacks(_ controller: ReaderZoomFixtureViewController) {
        controller.onSnapshot = { [weak controller] text in
            guard let controller else { return }
            onSnapshot(controller.sessionID, text)
        }
        controller.onSingleTap = onSingleTap
    }
}
#endif
