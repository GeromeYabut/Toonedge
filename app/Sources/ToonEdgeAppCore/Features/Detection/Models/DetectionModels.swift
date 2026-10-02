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
    /// Zero means an older payload did not measure viewport height; never infer it from width.
    public var viewportHeight: Double
    public var hardBlocks: [DetectionHardBlock]

    public init(
        pageURL: URL,
        title: String,
        documentHeight: Double,
        viewportWidth: Double,
        images: [DetectionImageCandidate],
        previousChapterURL: URL? = nil,
        nextChapterURL: URL? = nil,
        challengeSignals: [String] = [],
        viewportHeight: Double = 0,
        hardBlocks: [DetectionHardBlock] = []
    ) {
        self.pageURL = pageURL
        self.title = title
        self.documentHeight = documentHeight
        self.viewportWidth = viewportWidth
        self.images = images
        self.previousChapterURL = previousChapterURL
        self.nextChapterURL = nextChapterURL
        self.challengeSignals = challengeSignals
        self.viewportHeight = viewportHeight
        self.hardBlocks = hardBlocks
    }

    private enum CodingKeys: String, CodingKey {
        case pageURL, title, documentHeight, viewportWidth, images
        case previousChapterURL, nextChapterURL, challengeSignals, viewportHeight, hardBlocks
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            pageURL: try values.decode(URL.self, forKey: .pageURL),
            title: try values.decode(String.self, forKey: .title),
            documentHeight: try values.decode(Double.self, forKey: .documentHeight),
            viewportWidth: try values.decode(Double.self, forKey: .viewportWidth),
            images: try values.decode([DetectionImageCandidate].self, forKey: .images),
            previousChapterURL: try values.decodeIfPresent(URL.self, forKey: .previousChapterURL),
            nextChapterURL: try values.decodeIfPresent(URL.self, forKey: .nextChapterURL),
            challengeSignals: try values.decodeIfPresent([String].self, forKey: .challengeSignals) ?? [],
            viewportHeight: try values.decodeIfPresent(Double.self, forKey: .viewportHeight) ?? 0,
            hardBlocks: try values.decodeIfPresent([DetectionHardBlock].self, forKey: .hardBlocks) ?? []
        )
    }

    var resolvedHardBlocks: Set<DetectionHardBlock> {
        var blocks = Set(hardBlocks)
        if !challengeSignals.isEmpty || title.lowercased().contains("just a moment") {
            blocks.insert(.challenge)
        }
        return blocks
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
    public var readerEntryDisposition: ReaderEntryDisposition

    public init(
        pageURL: URL,
        confidence: DetectionConfidence,
        score: Int,
        candidates: [DetectionImageCandidate],
        readerSession: MockReaderSession?,
        retryRecommendation: DetectionRetryRecommendation = .none,
        diagnostics: DetectionDiagnostics,
        readerEntryDisposition: ReaderEntryDisposition? = nil
    ) {
        self.pageURL = pageURL
        self.confidence = confidence
        self.score = score
        self.candidates = candidates
        self.retryRecommendation = retryRecommendation
        self.diagnostics = diagnostics
        if !diagnostics.hardBlocks.isEmpty || readerSession == nil {
            self.readerEntryDisposition = .unavailable
        } else if let readerEntryDisposition {
            self.readerEntryDisposition = readerEntryDisposition
        } else {
            // Keep existing injected result initializers compatible while detectors supply explicit policy output.
            switch confidence {
            case .high: self.readerEntryDisposition = .automatic
            case .medium: self.readerEntryDisposition = .recommended
            case .low: self.readerEntryDisposition = .unavailable
            }
        }
        self.readerSession = self.readerEntryDisposition == .unavailable ? nil : readerSession
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
    public var hardBlocks: Set<DetectionHardBlock>
    public var negativeScore: Int
    public var tallestHeightRatio: Double

    public init(
        confidence: DetectionConfidence,
        score: Int,
        parserPath: DetectionParserPath,
        profileDomain: String? = nil,
        supportTier: SiteProfileSupportTier? = nil,
        compatibilityClass: SiteProfileCompatibilityClass? = nil,
        retryRecommendation: DetectionRetryRecommendation = .none,
        candidateCount: Int = 0,
        messages: [String] = [],
        hardBlocks: Set<DetectionHardBlock> = [],
        negativeScore: Int = 0,
        tallestHeightRatio: Double = 0
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
        self.hardBlocks = hardBlocks
        self.negativeScore = negativeScore
        self.tallestHeightRatio = tallestHeightRatio
    }

    private enum CodingKeys: String, CodingKey {
        case confidence, score, parserPath, profileDomain, supportTier, compatibilityClass
        case retryRecommendation, candidateCount, messages, hardBlocks, negativeScore, tallestHeightRatio
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            confidence: try values.decode(DetectionConfidence.self, forKey: .confidence),
            score: try values.decode(Int.self, forKey: .score),
            parserPath: try values.decode(DetectionParserPath.self, forKey: .parserPath),
            profileDomain: try values.decodeIfPresent(String.self, forKey: .profileDomain),
            supportTier: try values.decodeIfPresent(SiteProfileSupportTier.self, forKey: .supportTier),
            compatibilityClass: try values.decodeIfPresent(SiteProfileCompatibilityClass.self, forKey: .compatibilityClass),
            retryRecommendation: try values.decodeIfPresent(DetectionRetryRecommendation.self, forKey: .retryRecommendation) ?? .none,
            candidateCount: try values.decodeIfPresent(Int.self, forKey: .candidateCount) ?? 0,
            messages: try values.decodeIfPresent([String].self, forKey: .messages) ?? [],
            hardBlocks: try values.decodeIfPresent(Set<DetectionHardBlock>.self, forKey: .hardBlocks) ?? [],
            negativeScore: try values.decodeIfPresent(Int.self, forKey: .negativeScore) ?? 0,
            tallestHeightRatio: try values.decodeIfPresent(Double.self, forKey: .tallestHeightRatio) ?? 0
        )
    }
}
