import Foundation

public struct ProfileAwareChapterDetector: ChapterPageDetecting {
    private let registry: SiteProfileRegistry
    private let genericDetector: GenericChapterDetector
    private let diagnosticsLogger: any DetectionDiagnosticsLogging

    public init(
        registry: SiteProfileRegistry = .default,
        genericDetector: GenericChapterDetector = GenericChapterDetector(),
        diagnosticsLogger: any DetectionDiagnosticsLogging = OSLogDetectionDiagnosticsLogger()
    ) {
        self.registry = registry
        self.genericDetector = genericDetector
        self.diagnosticsLogger = diagnosticsLogger
    }

    public func detect(page: DetectionPageAnalysis) -> DetectionResult {
        let result: DetectionResult

        guard let profile = registry.profile(for: page.pageURL) else {
            result = genericDetector.detect(page: page, parserPath: .genericHeuristic)
            diagnosticsLogger.log(result.diagnostics, pageURL: page.pageURL)
            return result
        }

        if profile.compatibilityClass == .paginatedSinglePage {
            result = DetectionResult(
                pageURL: page.pageURL,
                confidence: .low,
                score: 0,
                candidates: [],
                readerSession: nil,
                diagnostics: DetectionDiagnostics(
                    confidence: .low,
                    score: 0,
                    parserPath: .unsupportedPaginatedProfile,
                    profileDomain: profile.domain,
                    supportTier: profile.supportTier,
                    compatibilityClass: profile.compatibilityClass,
                    retryRecommendation: .none,
                    candidateCount: 0,
                    messages: [
                        "confidence=low",
                        "score=0",
                        "candidateCount=0",
                        "parserPath=unsupportedPaginatedProfile",
                        "profileDomain=\(profile.domain)",
                        "supportTier=\(profile.supportTier.rawValue)",
                        "compatibilityClass=\(profile.compatibilityClass.rawValue)"
                    ],
                    hardBlocks: page.resolvedHardBlocks.union([.unsupportedPagination])
                )
            )
            diagnosticsLogger.log(result.diagnostics, pageURL: page.pageURL)
            return result
        }

        guard profile.supportTier != .browserOnly else {
            result = DetectionResult(
                pageURL: page.pageURL,
                confidence: .low,
                score: 0,
                candidates: [],
                readerSession: nil,
                diagnostics: DetectionDiagnostics(
                    confidence: .low,
                    score: 0,
                    parserPath: .browserOnlyProfile,
                    profileDomain: profile.domain,
                    supportTier: profile.supportTier,
                    compatibilityClass: profile.compatibilityClass,
                    retryRecommendation: .none,
                    candidateCount: 0,
                    messages: [
                        "confidence=low",
                        "score=0",
                        "candidateCount=0",
                        "parserPath=browserOnlyProfile",
                        "profileDomain=\(profile.domain)",
                        "supportTier=\(profile.supportTier.rawValue)",
                        "compatibilityClass=\(profile.compatibilityClass.rawValue)"
                    ],
                    hardBlocks: page.resolvedHardBlocks.union([.browserOnly])
                )
            )
            diagnosticsLogger.log(result.diagnostics, pageURL: page.pageURL)
            return result
        }

        if !page.resolvedHardBlocks.isEmpty {
            result = genericDetector.detect(page: page, parserPath: .browserSessionProfile, profile: profile)
            diagnosticsLogger.log(result.diagnostics, pageURL: page.pageURL)
            return result
        }

        guard profile.compatibilityClass != .browserSession else {
            result = DetectionResult(
                pageURL: page.pageURL,
                confidence: .low,
                score: 0,
                candidates: [],
                readerSession: nil,
                retryRecommendation: .browserSessionFollowUp,
                diagnostics: DetectionDiagnostics(
                    confidence: .low,
                    score: 0,
                    parserPath: .browserSessionProfile,
                    profileDomain: profile.domain,
                    supportTier: profile.supportTier,
                    compatibilityClass: profile.compatibilityClass,
                    retryRecommendation: .browserSessionFollowUp,
                    candidateCount: 0,
                    messages: [
                        "confidence=low",
                        "score=0",
                        "candidateCount=0",
                        "parserPath=browserSessionProfile",
                        "profileDomain=\(profile.domain)",
                        "supportTier=\(profile.supportTier.rawValue)",
                        "compatibilityClass=\(profile.compatibilityClass.rawValue)"
                    ]
                )
            )
            diagnosticsLogger.log(result.diagnostics, pageURL: page.pageURL)
            return result
        }

        let profiledPage = page.withImagesMatching(profile.imageSelectorHints)
        let hasProfileCandidates = !profiledPage.images.isEmpty
        let detectionPage = hasProfileCandidates ? profiledPage : page
        let parserPath: DetectionParserPath = hasProfileCandidates ? .siteProfile : .genericHeuristic
        result = genericDetector.detect(page: detectionPage, parserPath: parserPath, profile: profile)
        diagnosticsLogger.log(result.diagnostics, pageURL: page.pageURL)
        return result
    }

    public func detectBrowserSessionFollowUp(page: DetectionPageAnalysis) -> DetectionResult {
        guard let profile = registry.profile(for: page.pageURL),
              profile.compatibilityClass == .browserSession,
              profile.supportTier != .browserOnly else {
            return detect(page: page)
        }

        let result = genericDetector.detect(page: page, parserPath: .siteProfile, profile: profile)
        diagnosticsLogger.log(result.diagnostics, pageURL: page.pageURL)
        return result
    }
}

private extension DetectionPageAnalysis {
    func withImagesMatching(_ selectorHints: [String]) -> DetectionPageAnalysis {
        let normalizedHints = selectorHints
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !normalizedHints.isEmpty else {
            return self
        }

        var copy = self
        copy.images = images.filter { candidate in
            let haystack = [
                candidate.className,
                candidate.id,
                candidate.alt,
                candidate.parentSignature
            ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

            return normalizedHints.contains { haystack.contains($0) }
        }
        return copy
    }
}
