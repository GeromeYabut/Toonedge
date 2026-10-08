import CoreGraphics
import Foundation

extension ReaderInteractionCoordinator {
    func matchesGesture(_ gesture: ReaderGestureToken, basis: ReaderInteractionToken,
                        allowPendingGeometry: Bool = false) -> Bool {
        guard !isSuspended, activeGesture == gesture,
              gesture.sessionID == sessionID, gesture.installationID == installationID,
              gesture.interactionEpoch == interactionEpoch else { return false }
        return isCurrent(basis) || (allowPendingGeometry && pendingGeometry == basis &&
            basis.interactionEpoch == interactionEpoch &&
            basis.geometryRevision == latestRequestedRevision) ||
            (allowPendingGeometry && retiredPresentationToken == basis &&
             basis.sessionID == sessionID && basis.installationID == installationID &&
             basis.interactionEpoch == interactionEpoch &&
             basis.geometryRevision == latestRequestedRevision)
    }

    public mutating func beginGesture(from token: ReaderInteractionToken,
                                     epochID: UUID, requestID: UUID) -> ReaderGestureToken? {
        guard mayBegin, isCurrent(token), let current, let committed,
              current.scale != 1 || baselineReceipt != nil else { return nil }
        if current.scale == 1 { frozenReading = reading }
        rollback = committed; interactionEpoch = epochID; restoreWindowOpen = false
        let gesture = ReaderGestureToken(sessionID: sessionID,
            installationID: installationID, interactionEpoch: epochID)
        activeGesture = gesture
        guard issue(current, purpose: .inspection, requestID: requestID) else {
            activeGesture = nil; return nil
        }
        return gesture
    }

    public mutating func setInspectionScale(gesture: ReaderGestureToken,
                                           basedOn token: ReaderInteractionToken,
                                           scale: CGFloat, anchor: ReaderSemanticAnchor,
                                           viewportPoint: CGPoint, requestID: UUID) -> Bool {
        guard matchesGesture(gesture, basis: token), scale.isFinite, (0.75...3).contains(scale),
              let layout = validLayout,
              let transform = ReaderPresentationTransform(layout: layout, scale: scale,
                  anchor: anchor, viewportPoint: viewportPoint) else { return false }
        guard let target = ReaderSemanticPresentation.capture(transform, preferredAnchor: anchor)
        else { failure = .noContentTarget; return false }
        return issue(target, purpose: .inspection, requestID: requestID)
    }

    public mutating func panInspection(gesture: ReaderGestureToken,
                                      basedOn token: ReaderInteractionToken,
                                      delta: CGPoint, requestID: UUID) -> Bool {
        guard matchesGesture(gesture, basis: token), let layout = validLayout,
              let current, let transform = current.reproject(in: layout),
              let panned = transform.panned(by: delta) else { return false }
        guard let target = ReaderSemanticPresentation.capture(panned, preferredAnchor: current.anchor)
        else { failure = .noContentTarget; return false }
        return issue(target, purpose: .inspection, requestID: requestID)
    }

    public mutating func endGesture(_ gesture: ReaderGestureToken,
                                   basedOn token: ReaderInteractionToken, requestID: UUID) -> Bool {
        guard matchesGesture(gesture, basis: token, allowPendingGeometry: true), let current
        else { return false }
        activeGesture = nil; rollback = nil
        if current.scale == 1 {
            guard let target = frozenReading ?? reading else { block(.noContentTarget); return false }
            self.current = target; committed = target
            return issue(target, purpose: .baselineRestore, requestID: requestID)
        }
        committed = current
        return issue(current, purpose: .inspection, requestID: requestID)
    }

    public mutating func cancelGesture(_ gesture: ReaderGestureToken,
                                      basedOn token: ReaderInteractionToken, requestID: UUID) -> Bool {
        guard matchesGesture(gesture, basis: token, allowPendingGeometry: true), let rollback
        else { return false }
        activeGesture = nil; self.rollback = nil
        let target = rollback.scale == 1 ? (frozenReading ?? rollback) : rollback
        current = target; committed = target
        return issue(target, purpose: .rollback, requestID: requestID)
    }

    public mutating func inspect(from token: ReaderInteractionToken, scale: CGFloat,
                                anchor: ReaderSemanticAnchor, viewportPoint: CGPoint,
                                epochID: UUID, requestID: UUID) -> Bool {
        guard mayBegin, isCurrent(token) else { return false }
        if scale == 1 {
            return reset(installationID: installationID, epochID: epochID, requestID: requestID)
        }
        guard scale.isFinite, (0.75...3).contains(scale), let layout = validLayout,
              let transform = ReaderPresentationTransform(layout: layout, scale: scale,
                  anchor: anchor, viewportPoint: viewportPoint)
        else { return false }
        guard let target = ReaderSemanticPresentation.capture(transform, preferredAnchor: anchor)
        else { restoreWindowOpen = false; block(.noContentTarget); return false }
        if current?.scale == 1 { frozenReading = reading }
        interactionEpoch = epochID; restoreWindowOpen = false; committed = target
        return issue(target, purpose: .inspection, requestID: requestID)
    }

    public mutating func reset(installationID: UUID, epochID: UUID, requestID: UUID) -> Bool {
        guard installationID == self.installationID, !isSuspended else { return false }
        let target = frozenReading ?? reading ?? (current?.scale == 1 ? current : nil)
        interactionEpoch = epochID; activeGesture = nil; rollback = nil
        pendingGeometry = nil; restoreWindowOpen = false
        retiredPresentationToken = nil
        guard let target else { block(.noContentTarget); return false }
        current = target; committed = target
        return issue(target, purpose: .baselineRestore, requestID: requestID)
    }
}
