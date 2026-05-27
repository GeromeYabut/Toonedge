import Foundation

public enum SiteProfileSupportTier: String, Codable, Equatable, Sendable {
    case enabledPublic
    case approvedNonPromoted
    case browserOnly
}

public enum SiteProfileCompatibilityClass: String, Codable, Equatable, Sendable {
    case embeddedHTML
    case hydratedDOM
    case browserSession
    case browserOnly
    case paginatedSinglePage
}

public enum SiteProfileExtractionStrategy: Codable, Equatable, Sendable {
    case selectorHints([String])
}

public struct SiteProfileTemplate: Codable, Equatable, Sendable {
    public var compatibilityClass: SiteProfileCompatibilityClass
    public var extractionStrategy: SiteProfileExtractionStrategy

    public init(
        compatibilityClass: SiteProfileCompatibilityClass,
        extractionStrategy: SiteProfileExtractionStrategy
    ) {
        self.compatibilityClass = compatibilityClass
        self.extractionStrategy = extractionStrategy
    }

    public static let embeddedHTML = SiteProfileTemplate(
        compatibilityClass: .embeddedHTML,
        extractionStrategy: .selectorHints(["readerarea", "chapter", "reading-content", "main-reader"])
    )

    public static let hydratedDOM = SiteProfileTemplate(
        compatibilityClass: .hydratedDOM,
        extractionStrategy: .selectorHints(["reader", "page"])
    )

    public static let browserSession = SiteProfileTemplate(
        compatibilityClass: .browserSession,
        extractionStrategy: .selectorHints(["reader"])
    )

    public static let browserOnly = SiteProfileTemplate(
        compatibilityClass: .browserOnly,
        extractionStrategy: .selectorHints([])
    )

    public static let paginatedSinglePage = SiteProfileTemplate(
        compatibilityClass: .paginatedSinglePage,
        extractionStrategy: .selectorHints(["reader-main-img", "reader-main"])
    )
}

public struct SiteProfile: Codable, Equatable, Sendable {
    public var domain: String
    public var supportTier: SiteProfileSupportTier
    public var template: SiteProfileTemplate
    public var extractionStrategyOverride: SiteProfileExtractionStrategy?

    public init(
        domain: String,
        supportTier: SiteProfileSupportTier,
        template: SiteProfileTemplate
    ) {
        self.domain = domain.lowercased()
        self.supportTier = supportTier
        self.template = template
        self.extractionStrategyOverride = nil
    }

    public init(
        domain: String,
        supportTier: SiteProfileSupportTier,
        template: SiteProfileTemplate = .embeddedHTML,
        extractionStrategy: SiteProfileExtractionStrategy
    ) {
        self.domain = domain.lowercased()
        self.supportTier = supportTier
        self.template = template
        self.extractionStrategyOverride = extractionStrategy
    }

    public init(
        domain: String,
        supportTier: SiteProfileSupportTier,
        template: SiteProfileTemplate = .embeddedHTML,
        imageSelectorHints: [String]
    ) {
        self.init(
            domain: domain,
            supportTier: supportTier,
            template: template,
            extractionStrategy: .selectorHints(imageSelectorHints)
        )
    }

    public var compatibilityClass: SiteProfileCompatibilityClass {
        template.compatibilityClass
    }

    public var extractionStrategy: SiteProfileExtractionStrategy {
        extractionStrategyOverride ?? template.extractionStrategy
    }

    public var imageSelectorHints: [String] {
        switch extractionStrategy {
        case .selectorHints(let hints):
            hints
        }
    }
}

public struct SiteProfileRegistry: Sendable {
    public let profiles: [SiteProfile]

    public init(profiles: [SiteProfile]) {
        self.profiles = profiles
    }

    public func profile(for url: URL) -> SiteProfile? {
        guard let host = url.host()?.lowercased() else {
            return nil
        }

        return profiles
            .filter { profile in
                host == profile.domain || host.hasSuffix(".\(profile.domain)")
            }
            .sorted { $0.domain.count > $1.domain.count }
            .first
    }

    public var promotedSuggestionDomains: [String] {
        profiles
            .filter { $0.supportTier == .enabledPublic }
            .map(\.domain)
            .sorted()
    }

    public static let `default` = SiteProfileRegistry(
        profiles: [
            SiteProfile(
                domain: "webtoons.com",
                supportTier: .enabledPublic,
                template: .embeddedHTML,
                imageSelectorHints: ["viewer", "episode", "comic", "reader"]
            ),
            SiteProfile(
                domain: "globalcomix.com",
                supportTier: .enabledPublic,
                template: .embeddedHTML,
                imageSelectorHints: ["reader", "page", "comic"]
            ),
            SiteProfile(
                domain: "asuracomic.net",
                supportTier: .approvedNonPromoted,
                template: .embeddedHTML
            ),
            SiteProfile(
                domain: "asurascans.com",
                supportTier: .approvedNonPromoted,
                template: .embeddedHTML
            ),
            SiteProfile(
                domain: "manhwatop.com",
                supportTier: .approvedNonPromoted,
                template: .hydratedDOM,
                imageSelectorHints: ["chapter-content", "reading-content", "entry-content", "main-reader"]
            ),
            SiteProfile(
                domain: "manhuaus.com",
                supportTier: .approvedNonPromoted,
                template: .browserSession,
                imageSelectorHints: ["reading-content", "manga-reading-content", "wp-manga-chapter-img", "chapter"]
            ),
            SiteProfile(
                domain: "mangakatana.com",
                supportTier: .approvedNonPromoted,
                template: .hydratedDOM,
                imageSelectorHints: ["wrap_img", "page"]
            ),
            SiteProfile(
                domain: "mangafire.to",
                supportTier: .approvedNonPromoted,
                template: .browserSession,
                imageSelectorHints: ["page-wrapper", "reader"]
            ),
            SiteProfile(
                domain: "mangapill.com",
                supportTier: .approvedNonPromoted,
                template: .hydratedDOM,
                imageSelectorHints: ["js-page", "chapter-reader"]
            ),
            SiteProfile(
                domain: "mangahere.cc",
                supportTier: .browserOnly,
                template: .paginatedSinglePage
            )
        ]
    )
}
