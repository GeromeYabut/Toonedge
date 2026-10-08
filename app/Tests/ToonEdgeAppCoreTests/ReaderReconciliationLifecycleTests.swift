import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore

struct ReaderReconciliationLifecycleTests {
    @Test func initialRestoreSupersedesBootstrapBeforeUserInteraction() throws {
        var c = try readyCoordinator(heights: [600, 600])
        let original = try #require(c.request)
        let mutationResult1 = c.applyInitialRestore(installationID: c.installationID, index: 1, requestID: UUID())
        #expect(mutationResult1)
        let restored = try #require(c.request)
        #expect(restored.target.anchor.pageIndex == 1)
        let mutationResult2 = c.acknowledge(coordinatorMeasurement(original))
        #expect(!mutationResult2)
        #expect(c.baselineReceipt == nil)
        let mutationResult3 = c.acknowledge(coordinatorMeasurement(restored))
        #expect(mutationResult3)
        let mutationResult4 = c.applyInitialRestore(installationID: c.installationID, index: 0, requestID: UUID())
        #expect(!mutationResult4)
    }

    @Test func noSavedPositionKeepsDefaultAndEarlyRestoreWaitsForGeometry() throws {
        var c = try readyCoordinator()
        let original = c.request
        let mutationResult5 = c.applyInitialRestore(installationID: c.installationID, index: nil, requestID: UUID())
        #expect(mutationResult5)
        #expect(c.request == original)
        var early = try #require(ReaderInteractionCoordinator(sessionID: UUID(),
            installationID: UUID(), interactionEpoch: UUID(), pageCount: 2))
        let mutationResult6 = early.requestGeometry(revision: 0, requestID: UUID())
        let geometry = try #require(mutationResult6)
        let mutationResult7 = early.applyInitialRestore(installationID: early.installationID, index: 1, requestID: UUID())
        #expect(mutationResult7)
        #expect(early.request == nil)
        let mutationResult8 = early.resolveGeometry(geometry,
            layout: try coordinatorLayout(sessionID: early.sessionID, heights: [600, 600]),
            requestID: UUID())
        #expect(mutationResult8)
        #expect(early.request?.target.anchor.pageIndex == 1)
    }

    @Test func invalidOrForeignRestoreNeverSelectsArbitraryContent() throws {
        var c = try readyCoordinator()
        let before = c.request
        let mutationResult9 = c.applyInitialRestore(installationID: UUID(), index: 0, requestID: UUID())
        #expect(!mutationResult9)
        let mutationResult10 = c.applyInitialRestore(installationID: c.installationID, index: 4, requestID: UUID())
        #expect(!mutationResult10)
        #expect(c.request == before)
        let mutationResult11 = c.applyInitialRestore(installationID: c.installationID, index: 0, requestID: UUID())
        #expect(!mutationResult11)
    }

    @Test func baselineMovementRenewsReceiptWithoutIssuingApplication() throws {
        var c = try readyCoordinator()
        let original = try #require(c.request)
        let anchor = ReaderSemanticAnchor(sessionID: c.sessionID, pageIndex: 0,
            unitPoint: CGPoint(x: 0.5, y: 0.4))
        let measured = ReaderPresentationMeasurement(token: original.token, anchor: anchor,
            actualScale: 1, actualPoint: CGPoint(x: 100, y: 50),
            layoutCurrent: true, decodedCurrent: true)
        let mutationResult12 = c.recordBaselineReading(measured, requestID: UUID())
        #expect(mutationResult12)
        let current = try #require(c.request)
        #expect(current.token != original.token)
        #expect(current.requiresApplication == false)
        #expect(c.pendingApplicationRequest == nil)
        #expect(c.baselineReceipt?.target.anchor == anchor)
        let mutationResult13 = c.recordBaselineReading(measured, requestID: UUID())
        #expect(!mutationResult13)
        let mutationResult14 = c.applyInitialRestore(installationID: c.installationID, index: 0, requestID: UUID())
        #expect(!mutationResult14)
        let mutationResult15 = c.beginGesture(from: current.token, epochID: UUID(), requestID: UUID())
        #expect(mutationResult15 != nil)
        #expect(c.frozenReading?.anchor == anchor)
        #expect(c.frozenReading?.viewportPoint == CGPoint(x: 100, y: 50))
    }

    @Test func invalidMovementCannotRenewReadinessDuringInspectionOrPendingGeometry() throws {
        var c = try inspectedCoordinator()
        let inspected = try #require(c.request)
        let mutationResult16 = c.recordBaselineReading(coordinatorMeasurement(inspected, scale: 1), requestID: UUID())
        #expect(!mutationResult16)
        c = try readyCoordinator()
        let baseline = try #require(c.request)
        _ = c.requestGeometry(revision: 1, requestID: UUID())
        let mutationResult17 = c.recordBaselineReading(coordinatorMeasurement(baseline), requestID: UUID())
        #expect(!mutationResult17)
        #expect(c.baselineReceipt == nil)
    }

    @Test func suspensionRetiresGestureRestoreAndGeometryUntilFreshResume() throws {
        var c = try inspectedCoordinator()
        let mutationResult18 = c.beginGesture(from: try #require(c.request).token,
            epochID: UUID(), requestID: UUID())
        let gesture = try #require(mutationResult18)
        let sample = try #require(c.request).token
        let mutationResult19 = c.requestGeometry(revision: 1, requestID: UUID())
        let oldGeometry = try #require(mutationResult19)
        let mutationResult20 = c.suspend(installationID: c.installationID, epochID: UUID())
        #expect(mutationResult20)
        #expect(c.activeGesture == nil)
        #expect(c.pendingApplicationRequest == nil)
        let mutationResult21 = c.resolveGeometry(oldGeometry,
            layout: try coordinatorLayout(sessionID: c.sessionID, revision: 1), requestID: UUID())
        #expect(!mutationResult21)
        let mutationResult22 = c.resume(installationID: c.installationID, epochID: UUID(), revision: 1,
            requestID: UUID())
        #expect(mutationResult22 == nil)
        #expect(c.isSuspended)
        let mutationResult23 = c.resume(installationID: c.installationID, epochID: UUID(),
            revision: 2, requestID: UUID())
        let fresh = try #require(mutationResult23)
        let mutationResult24 = c.resolveGeometry(fresh,
            layout: try coordinatorLayout(sessionID: c.sessionID, revision: 2), requestID: UUID())
        #expect(mutationResult24)
        let mutationResult25 = c.acknowledge(coordinatorMeasurement(try #require(c.request)))
        #expect(mutationResult25)
        let mutationResult26 = c.panInspection(gesture: gesture, basedOn: sample, delta: .zero, requestID: UUID())
        #expect(!mutationResult26)
        let mutationResult27 = c.endGesture(gesture, basedOn: sample, requestID: UUID())
        #expect(!mutationResult27)
        let mutationResult28 = c.cancelGesture(gesture, basedOn: sample, requestID: UUID())
        #expect(!mutationResult28)
        let mutationResult29 = c.applyInitialRestore(installationID: c.installationID, index: 0, requestID: UUID())
        #expect(!mutationResult29)
        #expect(c.baselineReceipt == nil)
        let mutationResult30 = c.reset(installationID: c.installationID, epochID: UUID(), requestID: UUID())
        #expect(mutationResult30)
        let mutationResult31 = c.acknowledge(coordinatorMeasurement(try #require(c.request)))
        #expect(mutationResult31)
        #expect(c.baselineReceipt != nil)
    }

    @Test func resetAndInspectionRetireDelayedRestore() throws {
        for reset in [false, true] {
            var c = try readyCoordinator()
            if reset {
                let mutationResult32 = c.reset(installationID: c.installationID, epochID: UUID(), requestID: UUID())
                #expect(mutationResult32)
            } else {
                let mutationResult33 = c.beginGesture(from: try #require(c.request).token,
                    epochID: UUID(), requestID: UUID())
                #expect(mutationResult33 != nil)
            }
            let before = c.current
            let mutationResult34 = c.applyInitialRestore(installationID: c.installationID, index: 0, requestID: UUID())
            #expect(!mutationResult34)
            #expect(c.current == before)
        }
    }
}
