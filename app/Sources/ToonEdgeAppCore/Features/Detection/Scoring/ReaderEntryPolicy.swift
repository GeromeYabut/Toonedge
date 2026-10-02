public struct ReaderEntryPolicy: Equatable, Sendable {
    public static let architectureDefault = Self(manual: 45, medium: 55, high: 78)

    public let manual: Int
    public let medium: Int
    public let high: Int

    public init(manual: Int, medium: Int, high: Int) {
        self.manual = manual
        self.medium = medium
        self.high = high
    }

    public func disposition(for evidence: ReaderEntryEvidence) -> ReaderEntryDisposition {
        guard evidence.hardBlocks.isEmpty, evidence.hasViableSession else {
            return .unavailable
        }
        // Architecture §9.5.1 applies before every entry band, including manual attempts.
        guard evidence.candidateCount >= 4 || (evidence.candidateCount == 3
            && evidence.totalRenderedHeightRatio.isFinite && evidence.totalRenderedHeightRatio >= 3.5) else {
            return .unavailable
        }

        if evidence.score >= high {
            guard evidence.negativeScore > -20,
                  evidence.candidateCount >= 6 || evidence.tallestHeightRatio >= 5 else {
                return .unavailable
            }
            return .automatic
        }

        if evidence.score >= medium {
            guard evidence.candidateCount >= 4 || evidence.tallestHeightRatio >= 3.5 else {
                return .unavailable
            }
            return .recommended
        }

        return evidence.score >= manual ? .manual : .unavailable
    }
}
