import Foundation

public enum DetectionConfidence: String, Codable, Equatable, Sendable {
    case high
    case medium
    case low
}

public enum ReaderEntryDisposition: String, Codable, Equatable, Sendable {
    case automatic
    case recommended
    case manual
    case unavailable
}

public enum DetectionHardBlock: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case challenge
    case authentication
    case paywall
    case drm
    case errorPage
    case browserOnly
    case unsupportedPagination
    case protectedViewer
    case canvasOrBlob
    case nonviableSession
}

public struct ReaderEntryEvidence: Equatable, Sendable {
    public var score: Int
    public var negativeScore: Int
    public var candidateCount: Int
    public var tallestHeightRatio: Double
    public var hardBlocks: Set<DetectionHardBlock>
    public var hasViableSession: Bool

    public init(
        score: Int,
        negativeScore: Int,
        candidateCount: Int,
        tallestHeightRatio: Double,
        hardBlocks: Set<DetectionHardBlock>,
        hasViableSession: Bool
    ) {
        self.score = score
        self.negativeScore = negativeScore
        self.candidateCount = candidateCount
        self.tallestHeightRatio = tallestHeightRatio
        self.hardBlocks = hardBlocks
        self.hasViableSession = hasViableSession
    }
}

public enum DetectionParserPath: String, Codable, Equatable, Sendable {
    case siteProfile
    case genericHeuristic
    case browserSessionProfile
    case browserOnlyProfile
    case unsupportedPaginatedProfile
}

public enum DetectionRetryRecommendation: String, Codable, Equatable, Sendable {
    case none
    case browserSessionFollowUp
}

public struct DetectionImageCandidate: Codable, Equatable, Sendable {
    public var src: String?
    public var lazySources: [String]
    public var srcset: String?
    public var width: Double
    public var height: Double
    public var top: Double
    public var left: Double
    public var className: String?
    public var id: String?
    public var alt: String?
    public var parentSignature: String?
    public var semanticHints: [String]

    public init(
        src: String?,
        lazySources: [String],
        srcset: String?,
        width: Double,
        height: Double,
        top: Double,
        left: Double,
        className: String?,
        id: String?,
        alt: String?,
        parentSignature: String?,
        semanticHints: [String] = []
    ) {
        self.src = src
        self.lazySources = lazySources
        self.srcset = srcset
        self.width = width
        self.height = height
        self.top = top
        self.left = left
        self.className = className
        self.id = id
        self.alt = alt
        self.parentSignature = parentSignature
        self.semanticHints = semanticHints
    }
}

public struct DetectionPageAnalysis: Codable, Equatable, Sendable {
    public var pageURL: URL
    public var title: String
    public var documentHeight: Double
    public var viewportWidth: Double
    public var images: [DetectionImageCandidate]
    public var previousChapterURL: URL?
    public var nextChapterURL: URL?
    public var challengeSignals: [String]

    public init(
        pageURL: URL,
        title: String,
        documentHeight: Double,
        viewportWidth: Double,
        images: [DetectionImageCandidate],
        previousChapterURL: URL? = nil,
        nextChapterURL: URL? = nil,
        challengeSignals: [String] = []
    ) {
        self.pageURL = pageURL
        self.title = title
        self.documentHeight = documentHeight
        self.viewportWidth = viewportWidth
        self.images = images
        self.previousChapterURL = previousChapterURL
        self.nextChapterURL = nextChapterURL
        self.challengeSignals = challengeSignals
    }
}

public struct DetectionResult: Equatable, Sendable {
    public var pageURL: URL
    public var confidence: DetectionConfidence
    public var score: Int
    public var candidates: [DetectionImageCandidate]
    public var readerSession: MockReaderSession?
    public var retryRecommendation: DetectionRetryRecommendation
    public var diagnostics: DetectionDiagnostics

    public init(
        pageURL: URL,
        confidence: DetectionConfidence,
        score: Int,
        candidates: [DetectionImageCandidate],
        readerSession: MockReaderSession?,
        retryRecommendation: DetectionRetryRecommendation = .none,
        diagnostics: DetectionDiagnostics
    ) {
        self.pageURL = pageURL
        self.confidence = confidence
        self.score = score
        self.candidates = candidates
        self.readerSession = readerSession
        self.retryRecommendation = retryRecommendation
        self.diagnostics = diagnostics
    }
}

public struct DetectionDiagnostics: Codable, Equatable, Sendable {
    public var confidence: DetectionConfidence
    public var score: Int
    public var parserPath: DetectionParserPath
    public var profileDomain: String?
    public var supportTier: SiteProfileSupportTier?
    public var compatibilityClass: SiteProfileCompatibilityClass?
    public var retryRecommendation: DetectionRetryRecommendation
    public var candidateCount: Int
    public var messages: [String]

    public init(
        confidence: DetectionConfidence,
        score: Int,
        parserPath: DetectionParserPath,
        profileDomain: String? = nil,
        supportTier: SiteProfileSupportTier? = nil,
        compatibilityClass: SiteProfileCompatibilityClass? = nil,
        retryRecommendation: DetectionRetryRecommendation = .none,
        candidateCount: Int = 0,
        messages: [String] = []
    ) {
        self.confidence = confidence
        self.score = score
        self.parserPath = parserPath
        self.profileDomain = profileDomain
        self.supportTier = supportTier
        self.compatibilityClass = compatibilityClass
        self.retryRecommendation = retryRecommendation
        self.candidateCount = candidateCount
        self.messages = messages
    }
}
