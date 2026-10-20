#if canImport(UIKit)
import SwiftUI
import UIKit

struct ReaderSurfaceRequest {
    let id = UUID()
    let sessionID: UUID
    let pipelineID: ObjectIdentifier
    let command: ReaderSurfaceCommand
}

struct ReaderSurfaceHost: UIViewControllerRepresentable {
    let session: MockReaderSession
    let pipeline: ReaderPagePipeline
    let settings: ReaderSettings
    let palette: ReaderCanvasPaletteValues
    let request: ReaderSurfaceRequest?
    let restoreIndex: () async -> Int
    let onSingleTap: () -> Void
    let onBaselineSelection: (ReaderViewportSelection) -> Void

    final class Coordinator { var lastRequestID: UUID? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> ReaderSurfaceViewController {
        let controller = ReaderSurfaceViewController(session: session, pipeline: pipeline)
        install(controller)
        return controller
    }
    func updateUIViewController(_ controller: ReaderSurfaceViewController, context: Context) {
        install(controller)
        guard let request, request.sessionID == session.id,
              request.pipelineID == ObjectIdentifier(pipeline),
              request.id != context.coordinator.lastRequestID else { return }
        context.coordinator.lastRequestID = request.id
        controller.perform(request.command)
    }
    static func dismantleUIViewController(_ controller: ReaderSurfaceViewController, coordinator: Coordinator) {
        controller.stop()
    }
    private func install(_ controller: ReaderSurfaceViewController) {
        controller.restoreIndex = restoreIndex
        controller.onSingleTap = onSingleTap
        controller.onBaselineSelection = onBaselineSelection
        controller.configure(settings: settings, foreground: UIColor(palette.foreground.color),
            background: UIColor(palette.background.color))
    }
}
#endif
