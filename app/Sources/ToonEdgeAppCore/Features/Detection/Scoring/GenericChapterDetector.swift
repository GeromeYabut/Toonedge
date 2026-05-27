import Foundation

public struct GenericChapterDetector: ChapterPageDetecting {
    private let highConfidenceThreshold: Int
    private let mediumConfidenceThreshold: Int

    public init(highConfidenceThreshold: Int = 85, mediumConfidenceThreshold: Int = 45) {
        self.highConfidenceThreshold = highConfidenceThreshold
        self.mediumConfidenceThreshold = mediumConfidenceThreshold
    }

    public func detect(page: DetectionPageAnalysis) -> DetectionResult {
        if isChallengePage(page) {
            return challengeResult(for: page, parserPath: .genericHeuristic)
        }

        let normalizedCandidates = normalizedCandidates(from: page)
        let score = score(page: page, candidates: normalizedCandidates)
        let confidence: DetectionConfidence

        if score >= highConfidenceThreshold, normalizedCandidates.count >= 5 {
            confidence = .high
        } else if score >= mediumConfidenceThreshold, normalizedCandidates.count >= 2 {
            confidence = .medium
        } else {
            confidence = .low
        }

        let readerSession = confidence == .low ? nil : makeReaderSession(page: page, candidates: normalizedCandidates)

        return DetectionResult(
            pageURL: page.pageURL,
            confidence: readerSession == nil ? .low : confidence,
            score: score,
            candidates: normalizedCandidates,
            readerSession: readerSession,
            retryRecommendation: .none,
            diagnostics: diagnostics(
                page: page,
                confidence: readerSession == nil ? .low : confidence,
                candidates: normalizedCandidates,
                score: score,
                parserPath: .genericHeuristic
            )
        )
    }

    public func detect(
        page: DetectionPageAnalysis,
        parserPath: DetectionParserPath,
        profile: SiteProfile? = nil
    ) -> DetectionResult {
        if isChallengePage(page) {
            return challengeResult(for: page, parserPath: parserPath, profile: profile)
        }

        let normalizedCandidates = normalizedCandidates(from: page)
        let score = score(page: page, candidates: normalizedCandidates)
        let confidence: DetectionConfidence

        if score >= highConfidenceThreshold, normalizedCandidates.count >= 5 {
            confidence = .high
        } else if score >= mediumConfidenceThreshold, normalizedCandidates.count >= 2 {
            confidence = .medium
        } else {
            confidence = .low
        }

        let readerSession = confidence == .low ? nil : makeReaderSession(page: page, candidates: normalizedCandidates)
        let resolvedConfidence: DetectionConfidence = readerSession == nil ? .low : confidence

        return DetectionResult(
            pageURL: page.pageURL,
            confidence: resolvedConfidence,
            score: score,
            candidates: normalizedCandidates,
            readerSession: readerSession,
            retryRecommendation: .none,
            diagnostics: diagnostics(
                page: page,
                confidence: resolvedConfidence,
                candidates: normalizedCandidates,
                score: score,
                parserPath: parserPath,
                profile: profile
            )
        )
    }

    public func normalizedCandidates(from page: DetectionPageAnalysis) -> [DetectionImageCandidate] {
        var seenURLs = Set<URL>()

        return page.images
            .sorted { $0.top == $1.top ? $0.left < $1.left : $0.top < $1.top }
            .compactMap { candidate -> DetectionImageCandidate? in
                guard let resolvedURL = normalizedURL(for: candidate, pageURL: page.pageURL) else {
                    return nil
                }

                guard isUsable(candidate, resolvedURL: resolvedURL) else {
                    return nil
                }

                guard seenURLs.insert(resolvedURL).inserted else {
                    return nil
                }

                var normalized = candidate
                normalized.src = resolvedURL.absoluteString
                normalized.lazySources = []
                normalized.srcset = nil
                return normalized
            }
    }

    private func normalizedURL(for candidate: DetectionImageCandidate, pageURL: URL) -> URL? {
        let sources = candidate.lazySources + srcsetSources(candidate.srcset) + [candidate.src].compactMap { $0 }

        for source in sources {
            let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !isPlaceholderSource(trimmed) else {
                continue
            }

            if trimmed.hasPrefix("//") {
                return URL(string: "https:\(trimmed)")
            }

            if let absoluteURL = URL(string: trimmed), absoluteURL.scheme != nil {
                return absoluteURL
            }

            if let relativeURL = URL(string: trimmed, relativeTo: pageURL)?.absoluteURL {
                return relativeURL
            }
        }

        return nil
    }

    private func srcsetSources(_ srcset: String?) -> [String] {
        guard let srcset else {
            return []
        }

        return srcset
            .split(separator: ",")
            .compactMap { entry in
                entry
                    .split(whereSeparator: { $0.isWhitespace })
                    .first
                    .map(String.init)
            }
    }

    private func isPlaceholderSource(_ source: String) -> Bool {
        let lowercased = source.lowercased()
        return lowercased.hasPrefix("data:")
            || lowercased.contains("placeholder")
            || lowercased.contains("blank.gif")
            || lowercased.contains("spacer.gif")
    }

    private func isUsable(_ candidate: DetectionImageCandidate, resolvedURL: URL) -> Bool {
        guard hasStrongReaderHint(candidate) || (candidate.width >= 320 && candidate.height >= 500) else {
            return false
        }

        guard hasStrongReaderHint(candidate) || candidate.height / max(candidate.width, 1) >= 0.9 else {
            return false
        }

        let text = candidateText(candidate, resolvedURL: resolvedURL)
        let hardBlockHints = [
            "avatar", "logo", "icon", "sprite", "banner", "ad-", "/ad/", "/ads/", "ads-", "advert",
            "sponsor", "promo", "sidebar", "comment", "profile", "thumb", "thumbnail", "product"
        ]
        return !hardBlockHints.contains { text.contains($0) }
    }

    private func score(page: DetectionPageAnalysis, candidates: [DetectionImageCandidate]) -> Int {
        guard !candidates.isEmpty else {
            return 0
        }

        var score = 0
        let largeVerticalCount = candidates.filter { $0.width >= 600 && $0.height >= 900 }.count
        let readerTaggedCount = candidates.filter(hasStrongReaderHint).count

        score += min(40, largeVerticalCount * 6)
        score += min(44, readerTaggedCount * 4)
        score += min(18, candidates.count * 3)

        if page.documentHeight >= 6_000 {
            score += 12
        }

        if page.documentHeight >= 12_000 {
            score += 8
        }

        if hasSingleColumnFlow(candidates: candidates, viewportWidth: page.viewportWidth) {
            score += 18
        }

        if hasConsistentHost(candidates: candidates) {
            score += 8
        }

        if hasRepeatedPathShape(candidates: candidates) {
            score += 8
        }

        if isChapterLike(page: page) {
            score += 12
        }

        if candidates.count < 3 {
            score -= 16
        }

        return max(0, score)
    }

    private func hasStrongReaderHint(_ candidate: DetectionImageCandidate) -> Bool {
        let hints = candidate.semanticHints.map { $0.lowercased() }
        guard hints.contains("data-reader-page-image") else {
            return false
        }

        let text = [
            candidate.alt,
            candidate.className,
            candidate.parentSignature
        ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        return hints.contains("data-reader-index")
            || text.contains("chapter")
            || text.contains("page")
            || text.contains("reader")
    }

    private func hasSingleColumnFlow(candidates: [DetectionImageCandidate], viewportWidth: Double) -> Bool {
        guard candidates.count >= 2 else {
            return false
        }

        let sorted = candidates.sorted { $0.top < $1.top }
        let increasingTop = zip(sorted, sorted.dropFirst()).allSatisfy { previous, next in
            next.top > previous.top
        }
        let horizontallyClustered = sorted.allSatisfy { candidate in
            abs(candidate.left) <= max(80, viewportWidth * 0.25)
        }

        return increasingTop && horizontallyClustered
    }

    private func hasConsistentHost(candidates: [DetectionImageCandidate]) -> Bool {
        let hosts = Set(
            candidates
                .compactMap { $0.src }
                .compactMap(URL.init(string:))
                .compactMap { $0.host() }
        )
        return hosts.count == 1
    }

    private func hasRepeatedPathShape(candidates: [DetectionImageCandidate]) -> Bool {
        let pathPrefixes = candidates
            .compactMap { $0.src }
            .compactMap(URL.init(string:))
            .map { url in
                url.deletingLastPathComponent().path()
            }

        guard let first = pathPrefixes.first else {
            return false
        }

        return pathPrefixes.filter { $0 == first }.count >= max(2, candidates.count - 1)
    }

    private func isChapterLike(page: DetectionPageAnalysis) -> Bool {
        let haystack = "\(page.title) \(page.pageURL.absoluteString)".lowercased()
        let hints = ["chapter", "chap-", "chap_", "/chap", "/read", "episode", "webtoon", "manga", "manhwa"]
        return hints.contains { haystack.contains($0) }
    }

    private func makeReaderSession(page: DetectionPageAnalysis, candidates: [DetectionImageCandidate]) -> MockReaderSession? {
        let imageURLs = candidates
            .compactMap { $0.src }
            .compactMap(URL.init(string:))

        guard !imageURLs.isEmpty else {
            return nil
        }

        return MockReaderSession(
            seriesTitle: page.pageURL.host() ?? "Detected Chapter",
            seriesURL: CanonicalSeriesURLResolver.seriesURL(for: page.pageURL),
            chapterTitle: page.title.isEmpty ? "Detected Chapter" : page.title,
            sourceURL: page.pageURL,
            imageURLs: imageURLs,
            pageMetadata: candidates.map {
                ReaderPageMetadata(pixelWidth: $0.width, pixelHeight: $0.height)
            },
            previousChapter: page.previousChapterURL.map {
                MockChapter(title: "Previous Chapter", sourceURL: $0)
            },
            nextChapter: page.nextChapterURL.map {
                MockChapter(title: "Next Chapter", sourceURL: $0)
            },
            launchOrigin: .browser
        )
    }

    private func diagnostics(
        page: DetectionPageAnalysis,
        confidence: DetectionConfidence,
        candidates: [DetectionImageCandidate],
        score: Int,
        parserPath: DetectionParserPath,
        profile: SiteProfile? = nil
    ) -> DetectionDiagnostics {
        DetectionDiagnostics(
            confidence: confidence,
            score: score,
            parserPath: parserPath,
            profileDomain: profile?.domain,
            supportTier: profile?.supportTier,
            compatibilityClass: profile?.compatibilityClass,
            retryRecommendation: .none,
            candidateCount: candidates.count,
            messages: [
                "confidence=\(confidence.rawValue)",
                "score=\(score)",
                "candidateCount=\(candidates.count)",
                "documentHeight=\(Int(page.documentHeight))",
                "parserPath=\(parserPath.rawValue)",
                "compatibilityClass=\(profile?.compatibilityClass.rawValue ?? "none")"
            ]
        )
    }

    private func isChallengePage(_ page: DetectionPageAnalysis) -> Bool {
        if !page.challengeSignals.isEmpty {
            return true
        }

        let title = page.title.lowercased()
        return title.contains("just a moment")
    }

    private func challengeResult(
        for page: DetectionPageAnalysis,
        parserPath: DetectionParserPath,
        profile: SiteProfile? = nil
    ) -> DetectionResult {
        DetectionResult(
            pageURL: page.pageURL,
            confidence: .low,
            score: 0,
            candidates: [],
            readerSession: nil,
            diagnostics: DetectionDiagnostics(
                confidence: .low,
                score: 0,
                parserPath: parserPath,
                profileDomain: profile?.domain,
                supportTier: profile?.supportTier,
                compatibilityClass: profile?.compatibilityClass,
                retryRecommendation: .none,
                messages: [
                    "confidence=low",
                    "score=0",
                    "candidateCount=0",
                    "challengePage=true",
                    "parserPath=\(parserPath.rawValue)",
                    "compatibilityClass=\(profile?.compatibilityClass.rawValue ?? "none")"
                ]
            )
        )
    }

    private func candidateText(_ candidate: DetectionImageCandidate, resolvedURL: URL) -> String {
        [
            candidate.className,
            candidate.id,
            candidate.alt,
            candidate.parentSignature,
            candidate.semanticHints.joined(separator: " "),
            resolvedURL.absoluteString
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    }
}
