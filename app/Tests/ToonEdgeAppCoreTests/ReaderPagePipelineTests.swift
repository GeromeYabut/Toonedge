import Testing
@testable import ToonEdgeAppCore

@Test func prefetchWindowIncludesOneBehindAndTwoAhead() {
    let policy = ReaderPrefetchPolicy(behind: 1, ahead: 2, maximumConcurrentLoads: 3)

    #expect(policy.targetIndexes(current: 4, pageCount: 10) == [4, 5, 6, 3])
    #expect(policy.targetIndexes(current: 0, pageCount: 2) == [0, 1])
}
