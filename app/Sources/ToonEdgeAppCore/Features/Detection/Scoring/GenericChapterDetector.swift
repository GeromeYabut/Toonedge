import Foundation

public struct GenericChapterDetector: ChapterPageDetecting {
    private let entryPolicy: ReaderEntryPolicy

    public init(highConfidenceThreshold: Int = 78, mediumConfidenceThreshold: Int = 55) {
        self.entryPolicy = ReaderEntryPolicy(manual: 45, medium: mediumConfidenceThreshold, high: highConfidenceThreshold)
    }

    public init(entryPolicy: ReaderEntryPolicy) {
        self.entryPolicy = entryPolicy
    }

    public func detect(page: DetectionPageAnalysis) -> DetectionResult {
        detect(page: page, parserPath: .genericHeuristic)
    }

    public func detect(
        page: DetectionPageAnalysis,
        parserPath: DetectionParserPath,
        profile: SiteProfile? = nil
    ) -> DetectionResult {
        if page.resolvedHardBlocks.contains(.challenge) {
            return challengeResult(for: page, parserPath: parserPath, profile: profile)
        }

        let normalizedCandidates = normalizedCandidates(from: page)
        let scoring = score(page: page, candidates: normalizedCandidates)
        let session = scoring.total >= entryPolicy.manual
            ? makeReaderSession(page: page, candidates: normalizedCandidates) : nil
        var hardBlocks = page.resolvedHardBlocks
        if session == nil { hardBlocks.insert(.nonviableSession) }
        let tallestHeightRatio = page.viewportHeight.isFinite && page.viewportHeight > 0
            ? (normalizedCandidates.map(\.height).filter { $0.isFinite }.max() ?? 0) / page.viewportHeight : 0
        let evidence = ReaderEntryEvidence(
            score: scoring.total,
            negativeScore: scoring.negative,
            candidateCount: normalizedCandidates.count,
            tallestHeightRatio: tallestHeightRatio,
            hardBlocks: hardBlocks,
            hasViableSession: session != nil,
            totalRenderedHeightRatio: totalRenderedHeightRatio(candidates: normalizedCandidates, viewportHeight: page.viewportHeight)
        )
        let disposition = entryPolicy.disposition(for: evidence)
        let confidence: DetectionConfidence
        switch disposition {
        case .automatic: confidence = .high
        case .recommended: confidence = .medium
        case .manual, .unavailable: confidence = .low
        }

        return DetectionResult(
            pageURL: page.pageURL,
            confidence: confidence,
            score: scoring.total,
            candidates: normalizedCandidates,
            readerSession: disposition == .unavailable ? nil : session,
            retryRecommendation: .none,
            diagnostics: diagnostics(
                page: page,
                confidence: confidence,
                candidates: normalizedCandidates,
                evidence: evidence,
                parserPath: parserPath,
                profile: profile
            ),
            readerEntryDisposition: disposition
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

    private func totalRenderedHeightRatio(candidates: [DetectionImageCandidate], viewportHeight: Double) -> Double {
        guard viewportHeight.isFinite, viewportHeight > 0 else { return 0 }
        let heights = candidates.compactMap(\.renderedHeight)
        guard heights.count == candidates.count,
              heights.allSatisfy({ $0.isFinite && $0 > 0 }) else { return 0 }
        let ratio = heights.reduce(0, +) / viewportHeight
        return ratio.isFinite ? ratio : 0
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
        return lowercased.hasPrefix("data:") || lowercased.hasPrefix("blob:")
            || lowercased.contains("placeholder")
            || lowercased.contains("blank.gif")
            || lowercased.contains("spacer.gif")
    }

    private func isUsable(_ candidate: DetectionImageCandidate, resolvedURL: URL) -> Bool {
        guard ["http", "https"].contains(resolvedURL.scheme?.lowercased() ?? ""),
              candidate.width.isFinite, candidate.height.isFinite,
              candidate.width >= 0, candidate.height >= 0 else {
            return false
        }
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

    private func score(page: DetectionPageAnalysis, candidates: [DetectionImageCandidate]) -> (total: Int, negative: Int) {
        guard !candidates.isEmpty else {
            return (0, 0)
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

        let negativeScore = candidates.count < 3 ? -16 : 0
        return (max(0, score + negativeScore), negativeScore)
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

        let inferredAdjacentChapters = inferredAdjacentChapters(for: page)

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
            } ?? inferredAdjacentChapters.previous,
            nextChapter: page.nextChapterURL.map {
                MockChapter(title: "Next Chapter", sourceURL: $0)
            } ?? inferredAdjacentChapters.next,
            launchOrigin: .browser
        )
    }

    private func inferredAdjacentChapters(for page: DetectionPageAnalysis) -> (previous: MockChapter?, next: MockChapter?) {
        guard let currentNumber = ChapterURLInference.integerChapterNumber(
            chapterNumber: nil,
            chapterLabel: page.title,
            title: page.pageURL.absoluteString
        ) else {
            return (nil, nil)
        }

        let currentChapter = ChapterURLInference.KnownChapter(
            number: currentNumber,
            sourceURL: page.pageURL
        )

        let previous: MockChapter?
        if currentNumber > 1,
           let previousURL = ChapterURLInference.inferredSourceURL(
            forChapter: currentNumber - 1,
            knownChapters: [currentChapter]
           ) {
            previous = MockChapter(title: "Chapter \(currentNumber - 1)", sourceURL: previousURL)
        } else {
            previous = nil
        }

        let next: MockChapter?
        if let nextURL = ChapterURLInference.inferredSourceURL(
            forChapter: currentNumber + 1,
            knownChapters: [currentChapter]
        ) {
            next = MockChapter(title: "Chapter \(currentNumber + 1)", sourceURL: nextURL)
        } else {
            next = nil
        }

        return (previous, next)
    }

    private func diagnostics(
        page: DetectionPageAnalysis,
        confidence: DetectionConfidence,
        candidates: [DetectionImageCandidate],
        evidence: ReaderEntryEvidence,
        parserPath: DetectionParserPath,
        profile: SiteProfile? = nil
    ) -> DetectionDiagnostics {
        DetectionDiagnostics(
            confidence: confidence,
            score: evidence.score,
            parserPath: parserPath,
            profileDomain: profile?.domain,
            supportTier: profile?.supportTier,
            compatibilityClass: profile?.compatibilityClass,
            retryRecommendation: .none,
            candidateCount: candidates.count,
            messages: [
                "confidence=\(confidence.rawValue)",
                "score=\(evidence.score)",
                "candidateCount=\(candidates.count)",
                "documentHeight=\(Int(page.documentHeight))",
                "parserPath=\(parserPath.rawValue)",
                "compatibilityClass=\(profile?.compatibilityClass.rawValue ?? "none")"
            ],
            hardBlocks: evidence.hardBlocks,
            negativeScore: evidence.negativeScore,
            tallestHeightRatio: evidence.tallestHeightRatio,
            totalRenderedHeightRatio: evidence.totalRenderedHeightRatio
        )
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
                ],
                hardBlocks: page.resolvedHardBlocks
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
