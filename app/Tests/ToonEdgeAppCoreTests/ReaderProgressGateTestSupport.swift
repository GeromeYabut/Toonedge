import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore

@MainActor
final class ReaderGateReadinessProbe {
    var owner = NSObject()
    var image: ReaderDecodedImage?
    init() throws {
        let context = try #require(CGContext(data: nil, width: 200, height: 600,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 600))
        let cgImage = try #require(context.makeImage())
        image = ReaderDecodedImage(cgImage: cgImage, pixelWidth: 200, pixelHeight: 600)
    }
    func readiness(at index: Int) -> ReaderPageReadiness? {
        image.map { ReaderPageReadiness(pipelineID: ObjectIdentifier(owner),
            pageIndex: index, image: $0) }
    }
}

func readerGateMeasurement(_ request: ReaderPresentationRequest,
                           point: CGPoint? = nil) -> ReaderPresentationMeasurement {
    ReaderPresentationMeasurement(token: request.token, anchor: request.target.anchor,
        actualScale: request.target.scale, actualPoint: point ?? request.target.viewportPoint,
        layoutCurrent: true, decodedCurrent: true)
}

@MainActor
final class ReaderProgressGateFixture {
    let session: MockReaderSession
    let probe: ReaderGateReadinessProbe
    let gate: ReaderProgressGate

    init(pageCount: Int = 1, restoreResolved: Bool = true,
         measuredOffset: CGPoint = .zero, existingSession: MockReaderSession? = nil) throws {
        session = existingSession ?? MockReaderSession(seriesTitle: "Owned Fixture", chapterTitle: "Chapter 1",
            sourceURL: URL(string: "https://example.com/owned/chapter-1")!,
            imageURLs: (0..<pageCount).map {
                URL(string: "https://example.com/owned/page-\($0).png")!
            })
        probe = try ReaderGateReadinessProbe()
        var coordinator = try #require(ReaderInteractionCoordinator(sessionID: session.id,
            installationID: UUID(), interactionEpoch: UUID(), pageCount: pageCount))
        if restoreResolved {
            let accepted = coordinator.applyInitialRestore(installationID: coordinator.installationID,
                index: nil, requestID: UUID())
            #expect(accepted)
        }
        let value = coordinator.requestGeometry(revision: 0, requestID: UUID())
        let token = try #require(value)
        let layout = try #require(ReaderFittedLayout(sessionID: session.id, revision: 0,
            viewportSize: CGSize(width: 200, height: 100), displayMode: .fitWidth,
            pageSpacing: 0, metadata: Array(repeating:
                ReaderPageMetadata(pixelWidth: 200, pixelHeight: 600), count: pageCount)))
        let resolved = coordinator.resolveGeometry(token, layout: layout, requestID: UUID())
        #expect(resolved)
        let request = try #require(coordinator.request)
        let point = CGPoint(x: request.target.viewportPoint.x + measuredOffset.x,
                            y: request.target.viewportPoint.y + measuredOffset.y)
        let acknowledged = coordinator.acknowledge(readerGateMeasurement(request, point: point))
        #expect(acknowledged)
        let capturedProbe = probe
        let candidateGate = ReaderProgressGate(session: session, coordinator: coordinator,
            pipelineID: ObjectIdentifier(probe.owner), readiness: { index in
                capturedProbe.readiness(at: index)
            })
        gate = try #require(candidateGate)
        try publishCurrentObservation()
    }

    func publishCurrentObservation() throws {
        let receipt = try #require(gate.coordinator.baselineReceipt)
        let transform = try #require(gate.coordinator.confirmed)
        let index = receipt.target.anchor.pageIndex
        let logical = transform.layout.geometry.pageFrames[index]
        let frame = CGRect(x: logical.minX * transform.scale + transform.translation.x,
            y: logical.minY * transform.scale + transform.translation.y,
            width: logical.width * transform.scale, height: logical.height * transform.scale)
        let accepted = gate.observe(ReaderProgressObservation(token: receipt.token,
            pipelineID: ObjectIdentifier(probe.owner), pageIndex: index,
            pageFrame: frame, targetAvailable: true))
        #expect(accepted)
    }

    func reading() throws -> ReaderAuthorizedReading {
        try #require(gate.admit(operationID: UUID(), readAt: Date(timeIntervalSince1970: 100)))
    }

    func acknowledgeCurrent() throws {
        let request = try #require(gate.coordinator.request)
        var accepted = false
        gate.transition { accepted = $0.acknowledge(readerGateMeasurement(request)) }
        #expect(accepted)
        try publishCurrentObservation()
    }

    func move(to index: Int) throws {
        let receipt = try #require(gate.coordinator.baselineReceipt)
        let measurement = ReaderPresentationMeasurement(token: receipt.token,
            anchor: ReaderSemanticAnchor(sessionID: session.id, pageIndex: index,
                unitPoint: CGPoint(x: 0.5, y: 0)), actualScale: 1,
            actualPoint: CGPoint(x: 100, y: 0), layoutCurrent: true, decodedCurrent: true)
        var accepted = false
        gate.transition { accepted = $0.recordBaselineReading(measurement, requestID: UUID()) }
        #expect(accepted)
        try publishCurrentObservation()
    }
}
