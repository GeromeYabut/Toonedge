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
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: .fixture(score: 78, candidateCount: 3, tallestHeightRatio: 5, totalRenderedHeightRatio: 5)) == .automatic)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: .fixture(score: 78, candidateCount: 0, tallestHeightRatio: 5)) == .unavailable)
}

@Test func entryPolicyRequiresMediumBandCandidateEvidenceWithoutFallingThrough() {
    let insufficient = ReaderEntryEvidence.fixture(score: 55, candidateCount: 3, tallestHeightRatio: 3.49, totalRenderedHeightRatio: 3.5)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: insufficient) == .unavailable)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: .fixture(score: 55, candidateCount: 4, tallestHeightRatio: 0)) == .recommended)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: .fixture(score: 55, candidateCount: 3, tallestHeightRatio: 3.5, totalRenderedHeightRatio: 3.5)) == .recommended)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: .fixture(score: 55, candidateCount: 0, tallestHeightRatio: 3.5)) == .unavailable)
}

@Test(arguments: [45, 54, 55, 77, 78, 100], [0, 1, 2])
func entryPolicyGlobalFloorRejectsFewerThanThreeEvenWhenTall(score: Int, count: Int) {
    let evidence = ReaderEntryEvidence.fixture(score: score, candidateCount: count, tallestHeightRatio: 100, totalRenderedHeightRatio: 100)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: evidence) == .unavailable)
}

@Test(arguments: [45, 55, 78])
func entryPolicyGlobalFloorRejectsThreeWithoutMeasuredCombinedHeight(score: Int) {
    let evidence = ReaderEntryEvidence.fixture(score: score, candidateCount: 3, tallestHeightRatio: 100)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: evidence) == .unavailable)
}

@Test(arguments: [(45, ReaderEntryDisposition.manual), (55, .recommended), (78, .automatic)])
func entryPolicyGlobalFloorHonorsCombinedHeightBoundary(score: Int, expected: ReaderEntryDisposition) {
    for ratio in [0, 3.499, Double.infinity, Double.nan] {
        let evidence = ReaderEntryEvidence.fixture(score: score, candidateCount: 3, tallestHeightRatio: 100, totalRenderedHeightRatio: ratio)
        #expect(ReaderEntryPolicy.architectureDefault.disposition(for: evidence) == .unavailable)
    }
    let boundary = ReaderEntryEvidence.fixture(score: score, candidateCount: 3, tallestHeightRatio: 100, totalRenderedHeightRatio: 3.5)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: boundary) == expected)
    let four = ReaderEntryEvidence.fixture(score: score, candidateCount: 4, tallestHeightRatio: 100)
    #expect(ReaderEntryPolicy.architectureDefault.disposition(for: four) == expected)
}

private extension ReaderEntryEvidence {
    static func fixture(
        score: Int,
        negativeScore: Int = 0,
        candidateCount: Int = 6,
        tallestHeightRatio: Double = 6,
        hardBlocks: Set<DetectionHardBlock> = [],
        hasViableSession: Bool = true,
        totalRenderedHeightRatio: Double = 0
    ) -> Self {
        Self(
            score: score,
            negativeScore: negativeScore,
            candidateCount: candidateCount,
            tallestHeightRatio: tallestHeightRatio,
            hardBlocks: hardBlocks,
            hasViableSession: hasViableSession,
            totalRenderedHeightRatio: totalRenderedHeightRatio
        )
    }
}
