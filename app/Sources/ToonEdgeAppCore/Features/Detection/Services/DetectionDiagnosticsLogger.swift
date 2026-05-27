import Foundation
import OSLog

public protocol DetectionDiagnosticsLogging: Sendable {
    func log(_ diagnostics: DetectionDiagnostics, pageURL: URL)
}

public struct OSLogDetectionDiagnosticsLogger: DetectionDiagnosticsLogging {
    private let logger: Logger

    public init(logger: Logger = Logger(subsystem: "com.toonedge.app", category: "Detection")) {
        self.logger = logger
    }

    public func log(_ diagnostics: DetectionDiagnostics, pageURL: URL) {
        logger.info(
            "Detection result url=\(pageURL.absoluteString, privacy: .public) confidence=\(diagnostics.confidence.rawValue, privacy: .public) parserPath=\(diagnostics.parserPath.rawValue, privacy: .public) profile=\(diagnostics.profileDomain ?? "none", privacy: .public) tier=\(diagnostics.supportTier?.rawValue ?? "none", privacy: .public) compatibility=\(diagnostics.compatibilityClass?.rawValue ?? "none", privacy: .public) retry=\(diagnostics.retryRecommendation.rawValue, privacy: .public) score=\(diagnostics.score, privacy: .public) candidates=\(diagnostics.candidateCount, privacy: .public)"
        )
    }
}
