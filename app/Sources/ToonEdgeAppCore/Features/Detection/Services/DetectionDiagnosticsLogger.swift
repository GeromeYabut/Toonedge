import Foundation
import OSLog

struct DetectionLogURLShape: Equatable, Sendable, CustomStringConvertible {
    let host: String
    let pathShape: String

    init(url: URL) {
        host = url.host()?.lowercased() ?? "unknown"
        let structural = Set(["series", "manga", "comics", "read", "chapter", "viewer"])
        let components = url.pathComponents
            .filter { $0 != "/" }
            .map { component -> String in
                let lowercased = component.lowercased()
                if structural.contains(lowercased) {
                    return lowercased
                }
                if component.range(of: #"[0-9]+"#, options: .regularExpression) != nil {
                    return component.replacingOccurrences(
                        of: #"[0-9]+"#,
                        with: ":number",
                        options: .regularExpression
                    )
                }
                return ":segment"
            }
        pathShape = "/" + components.joined(separator: "/")
    }

    var description: String { "host=\(host) path=\(pathShape)" }
}

public protocol DetectionDiagnosticsLogging: Sendable {
    func log(_ diagnostics: DetectionDiagnostics, pageURL: URL)
}

public struct OSLogDetectionDiagnosticsLogger: DetectionDiagnosticsLogging {
    private let logger: Logger

    public init(logger: Logger = Logger(subsystem: "com.toonedge.app", category: "Detection")) {
        self.logger = logger
    }

    public func log(_ diagnostics: DetectionDiagnostics, pageURL: URL) {
        let urlShape = DetectionLogURLShape(url: pageURL)
        logger.info(
            "Detection result host=\(urlShape.host, privacy: .public) path=\(urlShape.pathShape, privacy: .public) confidence=\(diagnostics.confidence.rawValue, privacy: .public) parserPath=\(diagnostics.parserPath.rawValue, privacy: .public) profile=\(diagnostics.profileDomain ?? "none", privacy: .public) tier=\(diagnostics.supportTier?.rawValue ?? "none", privacy: .public) compatibility=\(diagnostics.compatibilityClass?.rawValue ?? "none", privacy: .public) retry=\(diagnostics.retryRecommendation.rawValue, privacy: .public) score=\(diagnostics.score, privacy: .public) candidates=\(diagnostics.candidateCount, privacy: .public)"
        )
    }
}
