import Testing
@testable import ToonEdgeAppCore

@Test(arguments: [
    (44, ReaderEntryDisposition.unavailable),
    (45, .manual), (54, .manual),
    (55, .recommended), (77, .recommended),
    (78, .automatic)
])
func entryPolicyMapsScoreBands(score: Int, expected: ReaderEntryDisposition) {
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: .fixture(score: score)) == expected)
}

@Test(arguments: DetectionHardBlock.allCases)
func entryPolicyRejectsEveryHardBlock(block: DetectionHardBlock) {
    let evidence = ReaderEntryEvidence.fixture(score: 100, hardBlocks: [block])
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: evidence) == .unavailable)
}

@Test func entryPolicyRejectsDRM() {
    let evidence = ReaderEntryEvidence.fixture(score: 100, hardBlocks: [.drm])
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: evidence) == .unavailable)
}

@Test func entryPolicyRequiresViableSessionAtEveryBand() {
    for score in [45, 55, 78] {
        let evidence = ReaderEntryEvidence.fixture(score: score, hasViableSession: false)
        #expect(ReaderEntryPolicy.architectureDefault.disposition(for: evidence) == .unavailable)
    }
}

@Test func entryPolicyHonorsHighBandNegativeConstraintWithoutFallingThrough() {
    for negativeScore in [-20, -21] {
        let evidence = ReaderEntryEvidence.fixture(score: 78, negativeScore: negativeScore)
        #expect(ReaderEntryPolicy.architectureDefault.disposition(for: evidence) == .unavailable)
    }
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: .fixture(score: 78, negativeScore: -19)) == .automatic)
}

@Test func entryPolicyRequiresHighBandCandidateEvidenceWithoutFallingThrough() {
    let insufficient = ReaderEntryEvidence.fixture(score: 78, candidateCount: 5, tallestHeightRatio: 4.99)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: insufficient) == .unavailable)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: .fixture(score: 78, candidateCount: 6, tallestHeightRatio: 0)) == .automatic)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: .fixture(score: 78, candidateCount: 0, tallestHeightRatio: 5)) == .automatic)
}

@Test func entryPolicyRequiresMediumBandCandidateEvidenceWithoutFallingThrough() {
    let insufficient = ReaderEntryEvidence.fixture(score: 55, candidateCount: 3, tallestHeightRatio: 3.49)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: insufficient) == .unavailable)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: .fixture(score: 55, candidateCount: 4, tallestHeightRatio: 0)) == .recommended)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: .fixture(score: 55, candidateCount: 0, tallestHeightRatio: 3.5)) == .recommended)
}

private extension ReaderEntryEvidence {
    static func fixture(
        score: Int,
        negativeScore: Int = 0,
        candidateCount: Int = 6,
        tallestHeightRatio: Double = 6,
        hardBlocks: Set<DetectionHardBlock> = [],
        hasViableSession: Bool = true
    ) -> Self {
        Self(
            score: score,
            negativeScore: negativeScore,
            candidateCount: candidateCount,
            tallestHeightRatio: tallestHeightRatio,
            hardBlocks: hardBlocks,
            hasViableSession: hasViableSession
        )
    }
}
