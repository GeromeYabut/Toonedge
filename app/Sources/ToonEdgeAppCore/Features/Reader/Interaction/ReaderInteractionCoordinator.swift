import CoreGraphics
import Foundation

public struct ReaderInteractionCoordinator: Sendable {
    public let sessionID: UUID
    public let installationID: UUID
    public let pageCount: Int
    public internal(set) var interactionEpoch: UUID
    public internal(set) var latestRequestedRevision: UInt64?
    public internal(set) var layout: ReaderFittedLayout?
    public internal(set) var request: ReaderPresentationRequest?
    public internal(set) var confirmed: ReaderPresentationTransform?
    public internal(set) var current: ReaderSemanticPresentation?
    public internal(set) var committed: ReaderSemanticPresentation?
    public internal(set) var reading: ReaderSemanticPresentation?
    public internal(set) var frozenReading: ReaderSemanticPresentation?
    public internal(set) var activeGesture: ReaderGestureToken?
    public internal(set) var baselineReceipt: ReaderBaselineReceipt?
    public internal(set) var failure: ReaderReconciliationFailure?
    public internal(set) var retiredPresentationToken: ReaderInteractionToken?
    public internal(set) var isSuspended = false
    var pendingGeometry: ReaderInteractionToken?
    var rollback: ReaderSemanticPresentation?
    var applied = false
    var restoreWindowOpen = true
    var initialIndex = 0

    public var pendingApplicationRequest: ReaderPresentationRequest? {
        guard !applied, let request, request.requiresApplication, isCurrent(request.token)
        else { return nil }
        return request
    }

    public init?(sessionID: UUID, installationID: UUID, interactionEpoch: UUID, pageCount: Int) {
        guard pageCount >= 0 else { return nil }
        self.sessionID = sessionID; self.installationID = installationID
        self.interactionEpoch = interactionEpoch; self.pageCount = pageCount
    }

    var validLayout: ReaderFittedLayout? {
        guard !isSuspended, pendingGeometry == nil, let layout,
              layout.geometry.revision == latestRequestedRevision else { return nil }
        return layout
    }

    var mayBegin: Bool {
        !isSuspended && activeGesture == nil && applied && failure == nil &&
            request.map { isCurrent($0.token) } == true
    }

    func makeToken(revision: UInt64, requestID: UUID) -> ReaderInteractionToken {
        ReaderInteractionToken(sessionID: sessionID, installationID: installationID,
            geometryRevision: revision, interactionEpoch: interactionEpoch, requestID: requestID)
    }

    public func isCurrent(_ token: ReaderInteractionToken) -> Bool {
        !isSuspended && pendingGeometry == nil && request?.token == token &&
            token.sessionID == sessionID && token.installationID == installationID &&
            token.interactionEpoch == interactionEpoch &&
            token.geometryRevision == latestRequestedRevision &&
            layout?.geometry.revision == latestRequestedRevision
    }

    mutating func block(_ reason: ReaderReconciliationFailure,
                        basis: ReaderInteractionToken? = nil) {
        retiredPresentationToken = basis ?? request?.token ?? pendingGeometry ?? retiredPresentationToken
        failure = reason; request = nil; applied = false; baselineReceipt = nil
    }

    @discardableResult
    mutating func issue(_ target: ReaderSemanticPresentation,
                        purpose: ReaderPresentationPurpose, requestID: UUID) -> Bool {
        guard let layout = validLayout else { block(.awaitingGeometry); return false }
        guard let transform = target.reproject(in: layout) else {
            block(.unreachableTarget); return false
        }
        current = target
        request = ReaderPresentationRequest(token: makeToken(revision: layout.geometry.revision,
            requestID: requestID), target: target, transform: transform, purpose: purpose,
            requiresApplication: true)
        baselineReceipt = nil; applied = false; failure = nil
        retiredPresentationToken = nil
        return true
    }

    public mutating func requestGeometry(revision: UInt64,
                                        requestID: UUID) -> ReaderInteractionToken? {
        guard !isSuspended, latestRequestedRevision.map({ revision > $0 }) ?? true else { return nil }
        latestRequestedRevision = revision
        let token = makeToken(revision: revision, requestID: requestID)
        pendingGeometry = token; request = nil; baselineReceipt = nil; applied = false; failure = nil
        retiredPresentationToken = nil
        return token
    }

    @discardableResult
    public mutating func resolveGeometry(_ token: ReaderInteractionToken,
                                        layout candidate: ReaderFittedLayout?, requestID: UUID) -> Bool {
        guard !isSuspended, token == pendingGeometry,
              token.interactionEpoch == interactionEpoch,
              token.geometryRevision == latestRequestedRevision else { return false }
        pendingGeometry = nil
        guard let candidate, candidate.geometry.sessionID == sessionID,
              candidate.geometry.revision == latestRequestedRevision,
              candidate.geometry.pageFrames.count == pageCount else {
            block(.invalidGeometry, basis: token); return false
        }
        layout = candidate
        if let committed, committed.reproject(in: candidate) == nil {
            block(.unreachableTarget, basis: token); return false
        }
        if let rollback, rollback.reproject(in: candidate) == nil {
            block(.unreachableTarget, basis: token); return false
        }
        if current == nil {
            guard let target = ReaderSemanticPresentation.bootstrap(index: initialIndex, in: candidate)
            else { block(.noContentTarget); return false }
            current = target; committed = target
        }
        guard let current else { block(.noContentTarget); return false }
        let purpose: ReaderPresentationPurpose = activeGesture != nil || current.scale != 1
            ? .inspection : (reading == nil ? .initialRestore : .baselineRestore)
        let issued = issue(current, purpose: purpose, requestID: requestID)
        if !issued { retiredPresentationToken = token }
        return issued
    }

    /// Recovery ownership is not native application or progress permission.
    public mutating func retryPresentation(after token: ReaderInteractionToken,
                                          requestID: UUID) -> Bool {
        guard !isSuspended, failure != nil, request == nil,
              retiredPresentationToken == token,
              token.sessionID == sessionID, token.installationID == installationID,
              token.interactionEpoch == interactionEpoch,
              token.geometryRevision == latestRequestedRevision,
              let layout = validLayout, let current,
              committed.map({ $0.reproject(in: layout) != nil }) ?? true,
              rollback.map({ $0.reproject(in: layout) != nil }) ?? true else { return false }
        let purpose: ReaderPresentationPurpose = activeGesture != nil || current.scale != 1
            ? .inspection : (reading == nil ? .initialRestore : .baselineRestore)
        return issue(current, purpose: purpose, requestID: requestID)
    }

    @discardableResult
    public mutating func acknowledge(_ measurement: ReaderPresentationMeasurement) -> Bool {
        guard isCurrent(measurement.token), !applied, let request, let layout = validLayout
        else { return false }
        guard measurement.anchor == request.target.anchor,
              measurement.actualScale.isFinite,
              measurement.actualScale == request.target.scale,
              measurement.layoutCurrent, measurement.decodedCurrent,
              !layout.unresolvedPageIndexes.contains(measurement.anchor.pageIndex),
              ReaderSemanticPresentation.withinTolerance(measurement.actualPoint,
                  request.target.viewportPoint),
              let measuredTarget = ReaderSemanticPresentation(scale: measurement.actualScale,
                  anchor: measurement.anchor, viewportPoint: measurement.actualPoint),
              let measuredTransform = measuredTarget.reproject(in: layout) else {
            block(.measurementRejected); return false
        }
        confirmed = measuredTransform; current = measuredTarget; applied = true; failure = nil
        if activeGesture == nil, request.target.scale == 1, request.purpose != .inspection {
            reading = measuredTarget; committed = measuredTarget; frozenReading = nil
            baselineReceipt = ReaderBaselineReceipt(token: request.token, target: measuredTarget)
        } else if activeGesture == nil {
            committed = measuredTarget
        }
        return true
    }

    @discardableResult
    public mutating func failApplication(_ token: ReaderInteractionToken) -> Bool {
        guard isCurrent(token), !applied else { return false }
        block(.applicationFailed); return true
    }
}
