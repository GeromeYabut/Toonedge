import Foundation

/// Transient host identity; unrelated to repository transaction semantics.
struct ReaderSurfaceRestoreToken: Equatable, Sendable {
    let sessionID: UUID
    let pipelineID: UUID
    let interaction: UInt64
}
struct ReaderSurfaceContract: Sendable {
    let sessionID: UUID
    let pipelineID: UUID
    private(set) var interaction: UInt64 = 0
    var restoreToken: ReaderSurfaceRestoreToken {
        ReaderSurfaceRestoreToken(sessionID: sessionID, pipelineID: pipelineID, interaction: interaction)
    }
    mutating func userDidInteract() { interaction &+= 1 }
    func acceptsRestore(_ token: ReaderSurfaceRestoreToken) -> Bool {
        token == restoreToken && interaction == 0
    }
}
struct ReaderSurfacePageToken: Equatable, Sendable {
    let sessionID: UUID
    let pipelineID: UUID
    let index: Int
    let assignmentID: UUID
}
struct ReaderSurfacePageAssignment: Sendable {
    private(set) var token: ReaderSurfacePageToken?
    mutating func assign(sessionID: UUID, pipelineID: UUID, index: Int) -> ReaderSurfacePageToken {
        let next = ReaderSurfacePageToken(sessionID: sessionID, pipelineID: pipelineID,
            index: index, assignmentID: UUID())
        token = next
        return next
    }
    func matches(_ value: ReaderSurfacePageToken) -> Bool { token == value }
    mutating func clear() { token = nil }
}

/// Unusable detection dimensions remain unresolved until valid decoded metadata arrives.
enum ReaderEffectivePageMetadata {
    static func resolve(learned: ReaderPageMetadata?, declared: ReaderPageMetadata?) -> ReaderPageMetadata? {
        if let learned, isUsable(learned) { return learned }
        if let declared, isUsable(declared) { return declared }
        return nil
    }
    private static func isUsable(_ metadata: ReaderPageMetadata) -> Bool {
        metadata.pixelWidth.isFinite && metadata.pixelHeight.isFinite &&
            metadata.pixelWidth > 0 && metadata.pixelHeight > 0
    }
}
