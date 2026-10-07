import CoreGraphics
import Foundation

public struct ReaderInteractionToken: Equatable, Sendable {
    public let sessionID: UUID
    public let installationID: UUID
    public let geometryRevision: UInt64
    public let interactionEpoch: UUID
    public let requestID: UUID
    public init(sessionID: UUID, installationID: UUID, geometryRevision: UInt64,
                interactionEpoch: UUID, requestID: UUID) {
        self.sessionID = sessionID; self.installationID = installationID
        self.geometryRevision = geometryRevision; self.interactionEpoch = interactionEpoch
        self.requestID = requestID
    }
}

public struct ReaderGestureToken: Equatable, Sendable {
    public let sessionID: UUID
    public let installationID: UUID
    public let interactionEpoch: UUID
}

public enum ReaderPresentationPurpose: Equatable, Sendable {
    case initialRestore, inspection, rollback, baselineRestore
}

public enum ReaderReconciliationFailure: Equatable, Sendable {
    case invalidGeometry, awaitingGeometry, noContentTarget, unreachableTarget
    case measurementRejected, applicationFailed
}

public struct ReaderPresentationRequest: Equatable, Sendable {
    public let token: ReaderInteractionToken
    public let target: ReaderSemanticPresentation
    public let transform: ReaderPresentationTransform
    public let purpose: ReaderPresentationPurpose
    public let requiresApplication: Bool
}

public struct ReaderPresentationMeasurement: Equatable, Sendable {
    public let token: ReaderInteractionToken
    public let anchor: ReaderSemanticAnchor
    public let actualScale: CGFloat
    public let actualPoint: CGPoint
    public let layoutCurrent: Bool
    public let decodedCurrent: Bool
    public init(token: ReaderInteractionToken, anchor: ReaderSemanticAnchor,
                actualScale: CGFloat, actualPoint: CGPoint,
                layoutCurrent: Bool, decodedCurrent: Bool) {
        self.token = token; self.anchor = anchor; self.actualScale = actualScale
        self.actualPoint = actualPoint; self.layoutCurrent = layoutCurrent
        self.decodedCurrent = decodedCurrent
    }
}

/// Presentation precondition only; this is not repository commit authorization.
public struct ReaderBaselineReceipt: Equatable, Sendable {
    public let token: ReaderInteractionToken
    public let target: ReaderSemanticPresentation
}
