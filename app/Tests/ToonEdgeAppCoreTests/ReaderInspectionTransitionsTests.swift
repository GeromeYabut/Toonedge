import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore

func inspectedCoordinator(scale: CGFloat = 2) throws -> ReaderInteractionCoordinator {
    var c = try readyCoordinator()
    let requestedGesture = c.beginGesture(from: try #require(c.request).token,
        epochID: UUID(), requestID: UUID())
    let gesture = try #require(requestedGesture)
    let anchor = ReaderSemanticAnchor(sessionID: c.sessionID, pageIndex: 0,
        unitPoint: CGPoint(x: 0.5, y: 0.05))
    let scaled = c.setInspectionScale(gesture: gesture, basedOn: try #require(c.request).token,
        scale: scale, anchor: anchor, viewportPoint: CGPoint(x: 100, y: 30), requestID: UUID())
    #expect(scaled)
    let ended = c.endGesture(gesture, basedOn: try #require(c.request).token, requestID: UUID())
    #expect(ended)
    let acknowledged = c.acknowledge(coordinatorMeasurement(try #require(c.request)))
    #expect(acknowledged)
    #expect(c.baselineReceipt == nil)
    return c
}

struct ReaderInspectionTransitionsTests {
    @Test func inspectionFreezesReadingNotTheInspectedFocalTarget() throws {
        let c = try inspectedCoordinator()
        #expect(c.frozenReading?.anchor.unitPoint == CGPoint(x: 0.5, y: 0))
        #expect(c.current?.anchor.unitPoint == CGPoint(x: 0.5, y: 0.05))
        #expect(c.committed == c.current)
        #expect(c.activeGesture == nil)
    }

    @Test func repeatedResetRejectsOldAcknowledgementAndGestureEvents() throws {
        var c = try inspectedCoordinator()
        let requestedGesture = c.beginGesture(from: try #require(c.request).token,
            epochID: UUID(), requestID: UUID())
        let gesture = try #require(requestedGesture)
        let sample = try #require(c.request).token
        let firstReset = c.reset(installationID: c.installationID, epochID: UUID(), requestID: UUID())
        #expect(firstReset)
        let first = try #require(c.request)
        let secondReset = c.reset(installationID: c.installationID, epochID: UUID(), requestID: UUID())
        #expect(secondReset)
        let second = try #require(c.request)
        #expect(first.token != second.token)
        let firstAck = c.acknowledge(coordinatorMeasurement(first))
        #expect(!firstAck)
        let stalePan = c.panInspection(gesture: gesture, basedOn: sample, delta: .zero, requestID: UUID())
        #expect(!stalePan)
        let staleCancel = c.cancelGesture(gesture, basedOn: sample, requestID: UUID())
        #expect(!staleCancel)
        #expect(c.baselineReceipt == nil)
        let acknowledged = c.acknowledge(coordinatorMeasurement(second))
        #expect(acknowledged)
        #expect(c.baselineReceipt?.token == second.token)
        #expect(c.frozenReading == nil)
    }

    @Test func cancelReprojectsCommittedPresentationAfterGeometryChange() throws {
        for scale in [CGFloat(2), CGFloat(0.75)] {
            var c = try inspectedCoordinator(scale: scale)
            let committed = try #require(c.committed)
            let frozen = c.frozenReading
            let requestedGesture = c.beginGesture(from: try #require(c.request).token,
                epochID: UUID(), requestID: UUID())
            let gesture = try #require(requestedGesture)
            let scaled = c.setInspectionScale(gesture: gesture, basedOn: try #require(c.request).token,
                scale: 3, anchor: committed.anchor, viewportPoint: committed.viewportPoint,
                requestID: UUID())
            #expect(scaled)
            let requestedGeometry = c.requestGeometry(revision: 1, requestID: UUID())
            let geometry = try #require(requestedGeometry)
            let changed = try coordinatorLayout(sessionID: c.sessionID, revision: 1, heights: [1000])
            let resolved = c.resolveGeometry(geometry, layout: changed, requestID: UUID())
            #expect(resolved)
            let cancelled = c.cancelGesture(gesture, basedOn: try #require(c.request).token, requestID: UUID())
            #expect(cancelled)
            let rollback = try #require(c.request)
            #expect(rollback.target == committed)
            #expect(rollback.transform.layout.geometry.revision == 1)
            #expect(c.frozenReading == frozen)
            let acknowledged = c.acknowledge(coordinatorMeasurement(rollback))
            #expect(acknowledged)
            #expect(c.baselineReceipt == nil)
        }
    }

    @Test func baselineReleaseNeedsItsOwnCurrentAcknowledgement() throws {
        var c = try inspectedCoordinator()
        let requestedGesture = c.beginGesture(from: try #require(c.request).token,
            epochID: UUID(), requestID: UUID())
        let gesture = try #require(requestedGesture)
        let target = try #require(c.current)
        let scaled = c.setInspectionScale(gesture: gesture, basedOn: try #require(c.request).token,
            scale: 1, anchor: target.anchor, viewportPoint: target.viewportPoint, requestID: UUID())
        #expect(scaled)
        let active = try #require(c.request)
        let activeAck = c.acknowledge(coordinatorMeasurement(active))
        #expect(activeAck)
        #expect(c.baselineReceipt == nil)
        let ended = c.endGesture(gesture, basedOn: active.token, requestID: UUID())
        #expect(ended)
        let endedRequest = try #require(c.request)
        #expect(endedRequest.target.anchor.unitPoint == CGPoint(x: 0.5, y: 0))
        let staleAck = c.acknowledge(coordinatorMeasurement(active))
        #expect(!staleAck)
        #expect(c.baselineReceipt == nil)
        let endedAck = c.acknowledge(coordinatorMeasurement(endedRequest))
        #expect(endedAck)
        #expect(c.baselineReceipt != nil)
    }

    @Test func pendingApplicationCannotSeedAnotherGestureOrConfirmWrongScale() throws {
        var c = try readyCoordinator()
        let anchor = try #require(c.current).anchor
        let inspected = c.inspect(from: try #require(c.request).token, scale: 2,
            anchor: anchor, viewportPoint: CGPoint(x: 100, y: 0), epochID: UUID(), requestID: UUID())
        #expect(inspected)
        let pending = try #require(c.request)
        let blockedGesture = c.beginGesture(from: pending.token, epochID: UUID(), requestID: UUID())
        #expect(blockedGesture == nil)
        let wrongAck = c.acknowledge(coordinatorMeasurement(pending, scale: 1))
        #expect(!wrongAck)
        #expect(c.failure == .measurementRejected)
        let retried = c.retryPresentation(after: pending.token, requestID: UUID())
        #expect(retried)
        let retry = try #require(c.request)
        #expect(retry.target == pending.target)
        let staleAck = c.acknowledge(coordinatorMeasurement(pending))
        #expect(!staleAck)
        let retryAck = c.acknowledge(coordinatorMeasurement(retry))
        #expect(retryAck)
        #expect(c.baselineReceipt == nil)
        let reset = c.reset(installationID: c.installationID, epochID: UUID(), requestID: UUID())
        #expect(reset)
        let resetAck = c.acknowledge(coordinatorMeasurement(try #require(c.request)))
        #expect(resetAck)
    }

    @Test func pendingGeometryCanBeCancelledButResetRetiresItsEpoch() throws {
        var c = try inspectedCoordinator()
        let requestedGesture = c.beginGesture(from: try #require(c.request).token,
            epochID: UUID(), requestID: UUID())
        let gesture = try #require(requestedGesture)
        let requestedOne = c.requestGeometry(revision: 1, requestID: UUID())
        let one = try #require(requestedOne)
        let earlyCancel = c.cancelGesture(gesture, basedOn: one, requestID: UUID())
        #expect(!earlyCancel)
        #expect(c.activeGesture == nil)
        #expect(c.failure == .awaitingGeometry)
        let resolvedOne = c.resolveGeometry(one,
            layout: try coordinatorLayout(sessionID: c.sessionID, revision: 1), requestID: UUID())
        #expect(resolvedOne)
        let requestedTwo = c.requestGeometry(revision: 2, requestID: UUID())
        let two = try #require(requestedTwo)
        let reset = c.reset(installationID: c.installationID, epochID: UUID(), requestID: UUID())
        #expect(!reset)
        let resolvedTwo = c.resolveGeometry(two,
            layout: try coordinatorLayout(sessionID: c.sessionID, revision: 2), requestID: UUID())
        #expect(!resolvedTwo)
        let requestedThree = c.requestGeometry(revision: 3, requestID: UUID())
        let three = try #require(requestedThree)
        let resolvedThree = c.resolveGeometry(three,
            layout: try coordinatorLayout(sessionID: c.sessionID, revision: 3), requestID: UUID())
        #expect(resolvedThree)
        let acknowledged = c.acknowledge(coordinatorMeasurement(try #require(c.request)))
        #expect(acknowledged)
        #expect(c.baselineReceipt != nil)
    }

    @Test func invalidSamplesDoNotMutateValidTargetAndGapRejectsBeforeApplication() throws {
        var c = try readyCoordinator(heights: [10, 10])
        let requestedGeometry = c.requestGeometry(revision: 1, requestID: UUID())
        let geometry = try #require(requestedGeometry)
        let resolved = c.resolveGeometry(geometry,
            layout: try coordinatorLayout(sessionID: c.sessionID, revision: 1,
                heights: [10, 10], spacing: 300), requestID: UUID())
        #expect(resolved)
        let initialAck = c.acknowledge(coordinatorMeasurement(try #require(c.request)))
        #expect(initialAck)
        let beforeDiscrete = try #require(c.request)
        let edge = ReaderSemanticAnchor(sessionID: c.sessionID, pageIndex: 0,
            unitPoint: CGPoint(x: 0.5, y: 1))
        let gapInspect = c.inspect(from: beforeDiscrete.token, scale: 0.75,
            anchor: edge, viewportPoint: CGPoint(x: 100, y: 0), epochID: UUID(), requestID: UUID())
        #expect(!gapInspect)
        #expect(c.failure == .noContentTarget)
        #expect(c.current == beforeDiscrete.target)
        #expect(c.baselineReceipt == nil)
        #expect(c.pendingApplicationRequest == nil)
        let retryDiscrete = c.retryPresentation(after: beforeDiscrete.token, requestID: UUID())
        #expect(retryDiscrete)
        let retryAck = c.acknowledge(coordinatorMeasurement(try #require(c.request)))
        #expect(retryAck)
        let requestedGesture = c.beginGesture(from: try #require(c.request).token,
            epochID: UUID(), requestID: UUID())
        let gesture = try #require(requestedGesture)
        let before = try #require(c.request)
        let invalidScale = c.setInspectionScale(gesture: gesture, basedOn: before.token, scale: CGFloat.nan,
            anchor: before.target.anchor, viewportPoint: .zero, requestID: UUID())
        #expect(!invalidScale)
        #expect(c.request == before)
        let gapPan = c.panInspection(gesture: gesture, basedOn: before.token,
            delta: CGPoint(x: 0, y: -150), requestID: UUID())
        #expect(!gapPan)
        #expect(c.failure == .noContentTarget)
        #expect(c.request == before)
        let zeroPan = c.panInspection(gesture: gesture, basedOn: before.token, delta: .zero, requestID: UUID())
        #expect(zeroPan)
        #expect(c.failure == nil)
    }

    @Test func unreachableGeometryFailsWithoutRebasingFrozenTarget() throws {
        var c = try inspectedCoordinator()
        let frozen = c.frozenReading
        let requestedOne = c.requestGeometry(revision: 1, requestID: UUID())
        let one = try #require(requestedOne)
        let narrow = try coordinatorLayout(sessionID: c.sessionID, revision: 1,
            viewport: CGSize(width: 80, height: 20))
        let resolved = c.resolveGeometry(one, layout: narrow, requestID: UUID())
        #expect(!resolved)
        #expect(c.failure == .unreachableTarget)
        #expect(c.frozenReading == frozen)
        #expect(c.baselineReceipt == nil)
        let retried = c.retryPresentation(after: one, requestID: UUID())
        #expect(!retried)
    }

    @Test func activeFailuresRetainOnlyCurrentEndAndCancellationOwnership() throws {
        for failureKind in 0..<3 {
            for cancel in [false, true] {
                var c = try inspectedCoordinator()
                let requestedGesture = c.beginGesture(from: try #require(c.request).token,
                    epochID: UUID(), requestID: UUID())
                let gesture = try #require(requestedGesture)
                let older = try #require(c.request).token
                let target = try #require(c.current)
                let scaled = c.setInspectionScale(gesture: gesture, basedOn: older, scale: 3,
                    anchor: target.anchor, viewportPoint: target.viewportPoint, requestID: UUID())
                #expect(scaled)
                var failedBasis = try #require(c.request).token
                if failureKind == 0 {
                    let failed = c.failApplication(failedBasis)
                    #expect(failed)
                } else if failureKind == 1 {
                    let wrongAck = c.acknowledge(coordinatorMeasurement(try #require(c.request), scale: 1))
                    #expect(!wrongAck)
                } else {
                    let requestedFailureGeometry = c.requestGeometry(revision: 1, requestID: UUID())
                    failedBasis = try #require(requestedFailureGeometry)
                    let failed = c.resolveGeometry(failedBasis, layout: nil, requestID: UUID())
                    #expect(!failed)
                }
                #expect(c.retiredPresentationToken == failedBasis)
                #expect(!c.isCurrent(failedBasis))
                let staleCancel = c.cancelGesture(gesture, basedOn: older, requestID: UUID())
                #expect(!staleCancel)
                let issued: Bool
                if cancel { issued = c.cancelGesture(gesture, basedOn: failedBasis, requestID: UUID()) }
                else { issued = c.endGesture(gesture, basedOn: failedBasis, requestID: UUID()) }
                #expect(issued == (failureKind != 2))
                #expect(c.activeGesture == nil)
                #expect(c.current?.scale == (cancel ? 2 : 3))
                if failureKind == 2 {
                    let requestedFresh = c.requestGeometry(revision: 2, requestID: UUID())
                    let fresh = try #require(requestedFresh)
                    let freshResolved = c.resolveGeometry(fresh,
                        layout: try coordinatorLayout(sessionID: c.sessionID, revision: 2), requestID: UUID())
                    #expect(freshResolved)
                }
                let retried = c.retryPresentation(after: failedBasis, requestID: UUID())
                #expect(!retried)
                let finalAck = c.acknowledge(coordinatorMeasurement(try #require(c.request)))
                #expect(finalAck)
                #expect(c.baselineReceipt == nil)
            }
        }
    }
}
