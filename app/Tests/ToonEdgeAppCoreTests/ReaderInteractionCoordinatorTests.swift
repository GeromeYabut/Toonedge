import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore

func readyCoordinator(heights: [Double?] = [600]) throws -> ReaderInteractionCoordinator {
    var coordinator = try #require(ReaderInteractionCoordinator(sessionID: UUID(),
        installationID: UUID(), interactionEpoch: UUID(), pageCount: heights.count))
    let requestedGeometry = coordinator.requestGeometry(revision: 0, requestID: UUID())
    let geometry = try #require(requestedGeometry)
    let layout = try coordinatorLayout(sessionID: coordinator.sessionID, heights: heights)
    let resolvedGeometry = coordinator.resolveGeometry(geometry, layout: layout, requestID: UUID())
    #expect(resolvedGeometry)
    let request = try #require(coordinator.request)
    let acknowledged = coordinator.acknowledge(coordinatorMeasurement(request))
    #expect(acknowledged)
    #expect(coordinator.baselineReceipt != nil)
    return coordinator
}

struct ReaderInteractionCoordinatorTests {
    @Test func bootstrapNeverGrantsReadinessBeforeAcknowledgement() throws {
        var c = try #require(ReaderInteractionCoordinator(sessionID: UUID(),
            installationID: UUID(), interactionEpoch: UUID(), pageCount: 1))
        let requestedToken = c.requestGeometry(revision: 0, requestID: UUID())
        let token = try #require(requestedToken)
        let resolved = c.resolveGeometry(token,
            layout: try coordinatorLayout(sessionID: c.sessionID), requestID: UUID())
        #expect(resolved)
        #expect(c.baselineReceipt == nil)
        #expect(c.confirmed == nil)
        let request = try #require(c.request)
        let acknowledged = c.acknowledge(coordinatorMeasurement(request))
        #expect(acknowledged)
        #expect(c.baselineReceipt?.token == request.token)
        #expect(c.reading == request.target)
    }

    @Test func latestRequestedRevisionRetiresOlderValidWork() throws {
        var c = try readyCoordinator()
        let oldRequest = try #require(c.request)
        let firstGeometry = c.requestGeometry(revision: 1, requestID: UUID())
        let one = try #require(firstGeometry)
        let secondGeometry = c.requestGeometry(revision: 2, requestID: UUID())
        let two = try #require(secondGeometry)
        #expect(c.baselineReceipt == nil)
        #expect(!c.isCurrent(oldRequest.token))
        let resolvedOld = c.resolveGeometry(one,
            layout: try coordinatorLayout(sessionID: c.sessionID, revision: 1), requestID: UUID())
        #expect(!resolvedOld)
        let resolvedInvalid = c.resolveGeometry(two, layout: nil, requestID: UUID())
        #expect(!resolvedInvalid)
        #expect(c.latestRequestedRevision == 2)
        #expect(c.failure == .invalidGeometry)
        let repeatedGeometry = c.requestGeometry(revision: 2, requestID: UUID())
        #expect(repeatedGeometry == nil)
        let oldAcknowledged = c.acknowledge(coordinatorMeasurement(oldRequest))
        #expect(!oldAcknowledged)
        let thirdGeometry = c.requestGeometry(revision: 3, requestID: UUID())
        let three = try #require(thirdGeometry)
        let resolvedLatest = c.resolveGeometry(three,
            layout: try coordinatorLayout(sessionID: c.sessionID, revision: 3), requestID: UUID())
        #expect(resolvedLatest)
        let latestRequest = try #require(c.request)
        let acknowledgedLatest = c.acknowledge(coordinatorMeasurement(latestRequest))
        #expect(acknowledgedLatest)
    }

    @Test func measurementRequiresCurrentDecodedLayoutExactScaleAndTolerance() throws {
        let base = try readyCoordinator()
        for kind in 0..<5 {
            var c = base
            let requestedToken = c.requestGeometry(revision: 1, requestID: UUID())
            let token = try #require(requestedToken)
            let resolved = c.resolveGeometry(token,
                layout: try coordinatorLayout(sessionID: c.sessionID, revision: 1), requestID: UUID())
            #expect(resolved)
            let request = try #require(c.request)
            let measurement = coordinatorMeasurement(request,
                scale: kind == 0 ? 2 : nil,
                point: kind == 1 ? CGPoint(x: 103, y: 0) :
                    (kind == 2 ? CGPoint(x: CGFloat.nan, y: 0) : nil),
                layoutCurrent: kind != 3, decodedCurrent: kind != 4)
            let acknowledged = c.acknowledge(measurement)
            #expect(!acknowledged)
            #expect(c.failure == .measurementRejected)
            #expect(c.baselineReceipt == nil)
            #expect(c.request == nil)
        }
    }

    @Test func placeholderCannotProduceBaselineReceipt() throws {
        var c = try #require(ReaderInteractionCoordinator(sessionID: UUID(),
            installationID: UUID(), interactionEpoch: UUID(), pageCount: 1))
        let zeroValue = c.requestGeometry(revision: 0, requestID: UUID())
        let zero = try #require(zeroValue)
        let placeholderResolved = c.resolveGeometry(zero,
            layout: try coordinatorLayout(sessionID: c.sessionID, heights: [nil]), requestID: UUID())
        #expect(placeholderResolved)
        let placeholderRequest = try #require(c.request)
        let placeholderAcknowledged = c.acknowledge(coordinatorMeasurement(placeholderRequest))
        #expect(!placeholderAcknowledged)
        let oneValue = c.requestGeometry(revision: 1, requestID: UUID())
        let one = try #require(oneValue)
        let resolved = c.resolveGeometry(one,
            layout: try coordinatorLayout(sessionID: c.sessionID, revision: 1), requestID: UUID())
        #expect(resolved)
        let request = try #require(c.request)
        let acknowledged = c.acknowledge(coordinatorMeasurement(request))
        #expect(acknowledged)
    }

    @Test func emptyChapterAndChangedPageCountRemainBlocked() throws {
        var empty = try #require(ReaderInteractionCoordinator(sessionID: UUID(),
            installationID: UUID(), interactionEpoch: UUID(), pageCount: 0))
        let zeroValue = empty.requestGeometry(revision: 0, requestID: UUID())
        let zero = try #require(zeroValue)
        let emptyResolved = empty.resolveGeometry(zero,
            layout: try coordinatorLayout(sessionID: empty.sessionID, heights: []), requestID: UUID())
        #expect(!emptyResolved)
        #expect(empty.failure == .noContentTarget)
        var c = try readyCoordinator()
        let changedValue = c.requestGeometry(revision: 1, requestID: UUID())
        let changed = try #require(changedValue)
        let changedResolved = c.resolveGeometry(changed,
            layout: try coordinatorLayout(sessionID: c.sessionID, revision: 1, heights: [600, 600]),
            requestID: UUID())
        #expect(!changedResolved)
        #expect(c.failure == .invalidGeometry)
    }

    @Test func installationFencesSameContentCallbacksAndRevisionNeverWraps() throws {
        let first = try readyCoordinator()
        var replacement = try #require(ReaderInteractionCoordinator(sessionID: first.sessionID,
            installationID: UUID(), interactionEpoch: UUID(), pageCount: 1))
        let oldRequest = try #require(first.request)
        let oldAcknowledged = replacement.acknowledge(coordinatorMeasurement(oldRequest))
        #expect(!oldAcknowledged)
        let maximumValue = replacement.requestGeometry(revision: .max, requestID: UUID())
        let maximum = try #require(maximumValue)
        let maximumResolved = replacement.resolveGeometry(maximum,
            layout: try coordinatorLayout(sessionID: first.sessionID, revision: .max), requestID: UUID())
        #expect(maximumResolved)
        let wrappedGeometry = replacement.requestGeometry(revision: 0, requestID: UUID())
        #expect(wrappedGeometry == nil)
    }

    @Test func applicationFailureDoesNotRestoreAnOlderReceipt() throws {
        var c = try readyCoordinator()
        let tokenValue = c.requestGeometry(revision: 1, requestID: UUID())
        let token = try #require(tokenValue)
        let resolved = c.resolveGeometry(token,
            layout: try coordinatorLayout(sessionID: c.sessionID, revision: 1), requestID: UUID())
        #expect(resolved)
        let request = try #require(c.request)
        let failed = c.failApplication(request.token)
        #expect(failed)
        #expect(c.failure == .applicationFailed)
        #expect(c.baselineReceipt == nil)
        let staleAcknowledged = c.acknowledge(coordinatorMeasurement(request))
        #expect(!staleAcknowledged)
        let retried = c.retryPresentation(after: request.token, requestID: UUID())
        #expect(retried)
        let retry = try #require(c.request)
        #expect(retry.token != request.token)
        #expect(retry.target == request.target)
        let retriedAgain = c.retryPresentation(after: request.token, requestID: UUID())
        #expect(!retriedAgain)
        let retryAcknowledged = c.acknowledge(coordinatorMeasurement(retry))
        #expect(retryAcknowledged)
        #expect(c.baselineReceipt != nil)
    }
}
