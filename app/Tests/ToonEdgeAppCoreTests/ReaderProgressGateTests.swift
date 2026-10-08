import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore

@MainActor
struct ReaderProgressGateTests {
    @Test func receiptDoesNotBypassPendingInitialRestore() throws {
        let fixture = try ReaderProgressGateFixture(restoreResolved: false)
        #expect(fixture.gate.admit(operationID: UUID(), readAt: Date()) == nil)
        fixture.gate.transition {
            _ = $0.applyInitialRestore(installationID: $0.installationID, index: nil, requestID: UUID())
        }
        let reading = try fixture.reading()
        #expect(reading.authorization.allowsCommit(of: reading.progressEffect))
    }

    @Test func currentObservationRequiresPositiveAreaAndUsableTarget() throws {
        for available in [true, false] {
            let fixture = try ReaderProgressGateFixture(pageCount: 3)
            let old = try fixture.reading()
            if available {
                let token = try #require(fixture.gate.coordinator.baselineReceipt).token
                let measurement = ReaderPresentationMeasurement(token: token,
                    anchor: ReaderSemanticAnchor(sessionID: fixture.session.id, pageIndex: 0,
                        unitPoint: CGPoint(x: 0.5, y: 1)), actualScale: 1,
                    actualPoint: CGPoint(x: 100, y: 0), layoutCurrent: true, decodedCurrent: true)
                var moved = false
                fixture.gate.transition { moved = $0.recordBaselineReading(measurement, requestID: UUID()) }
                #expect(moved)
            }
            let receipt = try #require(fixture.gate.coordinator.baselineReceipt)
            let frame = available ? CGRect(x: 0, y: -600, width: 200, height: 600)
                                  : CGRect(x: 0, y: 0, width: 200, height: 600)
            let accepted = fixture.gate.observe(ReaderProgressObservation(token: receipt.token,
                pipelineID: ObjectIdentifier(fixture.probe.owner), pageIndex: 0,
                pageFrame: frame, targetAvailable: available))
            #expect(!accepted)
            #expect(!old.authorization.allowsCommit(of: old.progressEffect))
            #expect(fixture.gate.admit(operationID: UUID(), readAt: Date()) == nil)
        }
    }

    @Test func foreignObservationDoesNotRetireCurrentReading() throws {
        let fixture = try ReaderProgressGateFixture()
        let reading = try fixture.reading()
        let receipt = try #require(fixture.gate.coordinator.baselineReceipt)
        let foreign = NSObject()
        let accepted = fixture.gate.observe(ReaderProgressObservation(token: receipt.token,
            pipelineID: ObjectIdentifier(foreign), pageIndex: 0,
            pageFrame: CGRect(x: 0, y: 0, width: 200, height: 600), targetAvailable: true))
        #expect(!accepted)
        let wrongPage = fixture.gate.observe(ReaderProgressObservation(token: receipt.token,
            pipelineID: ObjectIdentifier(fixture.probe.owner), pageIndex: 1,
            pageFrame: CGRect(x: 0, y: 0, width: 200, height: 600), targetAvailable: true))
        #expect(!wrongPage)
        #expect(reading.authorization.allowsCommit(of: reading.progressEffect))
    }

    @Test func decodedLossRetiresOldLeaseEvenAfterImageReturns() throws {
        let fixture = try ReaderProgressGateFixture()
        let reading = try fixture.reading()
        let image = fixture.probe.image
        fixture.probe.image = nil
        fixture.gate.refreshReadiness()
        #expect(!reading.authorization.allowsCommit(of: reading.progressEffect))
        fixture.probe.image = image
        try fixture.publishCurrentObservation()
        let fresh = try fixture.reading()
        #expect(!reading.authorization.allowsCommit(of: reading.progressEffect))
        #expect(fresh.authorization.allowsCommit(of: fresh.progressEffect))
    }

    @Test func mismatchedDecodedDimensionsAreNotResolvedReadiness() throws {
        let fixture = try ReaderProgressGateFixture()
        let image = try #require(fixture.probe.image)
        fixture.probe.image = ReaderDecodedImage(cgImage: image.cgImage,
            pixelWidth: 200, pixelHeight: 1000)
        fixture.gate.refreshReadiness()
        #expect(fixture.gate.admit(operationID: UUID(), readAt: Date()) == nil)
    }

    @Test func inspectionAndRepeatedResetRequireLatestAcknowledgement() throws {
        let fixture = try ReaderProgressGateFixture()
        let reading = try fixture.reading()
        let baseline = try #require(fixture.gate.coordinator.request)
        fixture.gate.transition { _ = $0.beginGesture(from: baseline.token,
            epochID: UUID(), requestID: UUID()) }
        #expect(!reading.authorization.allowsCommit(of: reading.progressEffect))
        fixture.gate.transition { _ = $0.reset(installationID: $0.installationID,
            epochID: UUID(), requestID: UUID()) }
        let firstReset = try #require(fixture.gate.coordinator.request)
        fixture.gate.transition { _ = $0.reset(installationID: $0.installationID,
            epochID: UUID(), requestID: UUID()) }
        fixture.gate.transition { _ = $0.acknowledge(readerGateMeasurement(firstReset)) }
        #expect(fixture.gate.admit(operationID: UUID(), readAt: Date()) == nil)
        try fixture.acknowledgeCurrent()
        let fresh = try fixture.reading()
        #expect(fresh.authorization.allowsCommit(of: fresh.progressEffect))
    }

    @Test func requestedGeometryAndSuspensionRetireAuthorityImmediately() throws {
        for suspend in [true, false] {
            let fixture = try ReaderProgressGateFixture()
            let reading = try fixture.reading()
            fixture.gate.transition {
                if suspend { _ = $0.suspend(installationID: $0.installationID, epochID: UUID()) }
                else { _ = $0.requestGeometry(revision: 1, requestID: UUID()) }
            }
            #expect(!reading.authorization.allowsCommit(of: reading.progressEffect))
            #expect(fixture.gate.admit(operationID: UUID(), readAt: Date()) == nil)
        }
    }

    @Test func newerOperationAndWrongPayloadCannotUseOldAuthority() throws {
        let fixture = try ReaderProgressGateFixture()
        let old = try fixture.reading()
        let latest = try fixture.reading()
        #expect(!old.authorization.allowsCommit(of: old.progressEffect))
        #expect(latest.authorization.allowsCommit(of: latest.progressEffect))
        let wrong = ReaderReadingEffect.progress(latest.input.progress,
            sourceURL: URL(string: "https://example.com/other/chapter-2")!,
            readAt: latest.input.readAt)
        #expect(!latest.authorization.allowsCommit(of: wrong))
        #expect(latest.authorization.allowsCommit(of: latest.progressEffect))
    }

    @Test func terminalRetirementCannotBeReopenedBySameContentCallbacks() throws {
        let fixture = try ReaderProgressGateFixture()
        let reading = try fixture.reading()
        fixture.gate.retireInstallation()
        fixture.gate.transition { _ = $0.reset(installationID: $0.installationID,
            epochID: UUID(), requestID: UUID()) }
        #expect(!reading.authorization.allowsCommit(of: reading.progressEffect))
        #expect(fixture.gate.admit(operationID: UUID(), readAt: Date()) == nil)
        let replacement = try ReaderProgressGateFixture(existingSession: fixture.session)
        #expect(replacement.session.id == fixture.session.id)
        #expect(replacement.gate.coordinator.installationID != fixture.gate.coordinator.installationID)
        let fresh = try replacement.reading()
        #expect(fresh.authorization.allowsCommit(of: fresh.progressEffect))
    }

    @Test func backwardMovementCreatesFreshCapturedProgress() throws {
        let fixture = try ReaderProgressGateFixture(pageCount: 3)
        let first = try fixture.reading()
        try fixture.move(to: 2)
        let last = try fixture.reading()
        #expect(last.input.progress.currentImageIndex == 2)
        try fixture.move(to: 0)
        let back = try fixture.reading()
        #expect(back.input.progress.currentImageIndex == 0)
        #expect(!first.authorization.allowsCommit(of: first.progressEffect))
        #expect(!last.authorization.allowsCommit(of: last.progressEffect))
        #expect(back.authorization.allowsCommit(of: back.progressEffect))
    }

    @Test func acceptedMeasuredOffsetIsRetainedNotReplacedWithRequestedPoint() throws {
        let fixture = try ReaderProgressGateFixture(measuredOffset: CGPoint(x: 1, y: 0))
        let target = try #require(fixture.gate.coordinator.baselineReceipt?.target)
        #expect(target.viewportPoint == CGPoint(x: 101, y: 0))
        #expect(fixture.gate.coordinator.current == target)
        #expect(fixture.gate.coordinator.committed == target)
        #expect(fixture.gate.coordinator.reading == target)
        let reading = try fixture.reading()
        #expect(reading.authorization.allowsCommit(of: reading.progressEffect))
    }
}
