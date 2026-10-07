import CoreGraphics
import Foundation

extension ReaderInteractionCoordinator {
    public mutating func applyInitialRestore(installationID: UUID, index: Int?,
                                            requestID: UUID) -> Bool {
        guard !isSuspended, installationID == self.installationID, restoreWindowOpen else { return false }
        restoreWindowOpen = false
        guard let index else { return true }
        guard (0..<pageCount).contains(index) else { return false }
        initialIndex = index; current = nil; committed = nil; reading = nil; frozenReading = nil
        request = nil; baselineReceipt = nil; applied = false
        retiredPresentationToken = nil
        guard let layout = validLayout else { return true }
        guard let target = ReaderSemanticPresentation.bootstrap(index: index, in: layout)
        else { block(.noContentTarget); return false }
        current = target; committed = target
        return issue(target, purpose: .initialRestore, requestID: requestID)
    }

    public mutating func recordBaselineReading(_ measurement: ReaderPresentationMeasurement,
                                              requestID: UUID) -> Bool {
        guard !isSuspended, activeGesture == nil, applied,
              baselineReceipt?.token == measurement.token, isCurrent(measurement.token),
              measurement.actualScale == 1, measurement.layoutCurrent, measurement.decodedCurrent,
              let layout = validLayout,
              !layout.unresolvedPageIndexes.contains(measurement.anchor.pageIndex),
              let target = ReaderSemanticPresentation(scale: 1, anchor: measurement.anchor,
                  viewportPoint: measurement.actualPoint),
              let transform = target.reproject(in: layout) else { return false }
        let token = makeToken(revision: layout.geometry.revision, requestID: requestID)
        request = ReaderPresentationRequest(token: token, target: target, transform: transform,
            purpose: .baselineRestore, requiresApplication: false)
        current = target; committed = target; reading = target; frozenReading = nil
        confirmed = transform; applied = true; failure = nil; restoreWindowOpen = false
        retiredPresentationToken = nil
        baselineReceipt = ReaderBaselineReceipt(token: token, target: target)
        return true
    }

    public mutating func suspend(installationID: UUID, epochID: UUID) -> Bool {
        guard installationID == self.installationID, !isSuspended else { return false }
        interactionEpoch = epochID; isSuspended = true; activeGesture = nil; rollback = nil
        current = committed; layout = nil; confirmed = nil; pendingGeometry = nil
        request = nil; baselineReceipt = nil; applied = false; failure = nil; restoreWindowOpen = false
        retiredPresentationToken = nil
        return true
    }

    public mutating func resume(installationID: UUID, epochID: UUID,
                                revision: UInt64, requestID: UUID) -> ReaderInteractionToken? {
        guard installationID == self.installationID, isSuspended,
              latestRequestedRevision.map({ revision > $0 }) ?? true else { return nil }
        interactionEpoch = epochID; isSuspended = false
        return requestGeometry(revision: revision, requestID: requestID)
    }
}
