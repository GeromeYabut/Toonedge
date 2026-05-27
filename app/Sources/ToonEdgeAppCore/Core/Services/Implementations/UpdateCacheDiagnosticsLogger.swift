import Foundation

public struct UpdateCacheDiagnosticsLogger: UpdateCacheDiagnosticsLogging {
    public init() {}

    public func log(_ event: UpdateCacheDiagnosticEvent) async {
        // OSLog integration can be added here without changing service call sites.
    }

    public static func sanitizedSourceIdentity(for sourceURL: URL) -> String {
        let host = sourceURL.host() ?? "unknown-host"
        let hash = FileBackedChapterAssetCache.stableIdentifier(for: sourceURL.absoluteString)
        return "\(host)-\(hash)"
    }

    public static func cacheRemoveFailureEvent(sourceURL: URL) -> UpdateCacheDiagnosticEvent {
        .cacheRemoveFailed(
            sourceIdentity: sanitizedSourceIdentity(for: sourceURL),
            operation: "remove"
        )
    }
}
