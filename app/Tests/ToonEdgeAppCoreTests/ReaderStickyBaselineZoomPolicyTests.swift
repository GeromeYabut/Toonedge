import Foundation
import Testing
@testable import ToonEdgeAppCore

struct ReaderStickyBaselineZoomPolicyTests {
    struct Trace: Sendable {
        let samples: [Double]
        let scales: [Double]
    }

    @Test(arguments: [
        Trace(samples: [1, 1.5, 2], scales: [1, 1.5, 2]),
        Trace(samples: [2, 1.2, 1.02], scales: [2, 1.2, 1]),
        Trace(samples: [2, 0.5, 0.45, 0.4], scales: [2, 1, 1, 0.9090909090909091]),
        Trace(samples: [0.5, 0.44, 0.4], scales: [1, 1, 0.9090909090909091]),
        Trace(samples: [2, 0.9, 0.81, 0.891], scales: [2, 1, 1, 1.1]),
        Trace(samples: [2, 0.9, 0.72, 0.8, 0.9, 0.81],
              scales: [2, 1, 0.9090909090909091, 1.0101010101010102, 1.1363636363636365, 1]),
        Trace(samples: [100, 50], scales: [3, 1.5]),
        Trace(samples: [2, 0.5, 0.1, 0.11], scales: [2, 1, 0.75, 0.825]),
        Trace(samples: [2, 0.5, 0.5, 0.5], scales: [2, 1, 1, 1])
    ])
    func followsScaleTrace(trace: Trace) {
        #expect(trace.samples.count == trace.scales.count)
        var policy = ReaderStickyBaselineZoomPolicy()
        policy.beginPinch()
        for (sample, expected) in zip(trace.samples, trace.scales) {
            policy.updatePinch(magnification: sample)
            #expect(abs(policy.scale - expected) < 1e-10)
            #expect(policy.isPinching)
            #expect(policy.committedScale == 1)
        }
    }

    @Test func firstOvershootEngagesBeforeAnyBreakthrough() {
        var policy = ReaderStickyBaselineZoomPolicy()
        policy.beginPinch()
        policy.updatePinch(magnification: 0.01)
        #expect(policy.scale == 1)
        #expect(policy.phase == .heldAtBaseline)
        policy.updatePinch(magnification: 0.0088)
        #expect(policy.scale == 1)
        #expect(policy.phase == .crossedBelow)
        policy.updatePinch(magnification: 0.008)
        #expect(abs(policy.scale - 0.9090909090909091) < 1e-10)
    }

    @Test func equalPostEngagementMovementIgnoresSubdivision() {
        var sparse = ReaderStickyBaselineZoomPolicy()
        sparse.beginPinch()
        sparse.updatePinch(magnification: 0.9)
        var dense = sparse
        for sample in [0.87, 0.84, 0.81, 0.78, 0.75, 0.72] {
            dense.updatePinch(magnification: sample)
        }
        sparse.updatePinch(magnification: 0.72)
        #expect(abs(sparse.scale - dense.scale) < 1e-10)
        #expect(abs(sparse.scale - 0.9090909090909091) < 1e-10)
        #expect(sparse.phase == .crossedBelow)
        #expect(dense.phase == .crossedBelow)
    }

    @Test func thresholdCrossingAppliesExcessInSameSample() {
        var policy = ReaderStickyBaselineZoomPolicy()
        policy.beginPinch()
        policy.updatePinch(magnification: 0.9)
        policy.updatePinch(magnification: 0.72)
        #expect(policy.phase == .crossedBelow)
        #expect(abs(policy.scale - 0.9090909090909091) < 1e-10)
    }

    @Test func engagementOvershootExceptionIsExplicit() {
        var early = ReaderStickyBaselineZoomPolicy()
        early.beginPinch()
        early.updatePinch(magnification: 1.02)
        early.updatePinch(magnification: 1.01)
        early.updatePinch(magnification: 0.88)
        var late = ReaderStickyBaselineZoomPolicy()
        late.beginPinch()
        late.updatePinch(magnification: 0.88)
        #expect(early.phase == .crossedBelow)
        #expect(early.scale < 1)
        #expect(late.phase == .heldAtBaseline)
        #expect(late.scale == 1)
    }

    @Test func invalidAndDuplicateSamplesPreserveEntirePolicy() {
        var policy = ReaderStickyBaselineZoomPolicy()
        policy.beginPinch()
        policy.updatePinch(magnification: 0.9)
        policy.updatePinch(magnification: 0.81)
        let held = policy
        for sample in [0.81, 0, -1, Double.nan, Double.infinity, -Double.infinity] {
            policy.updatePinch(magnification: sample)
            #expect(policy == held)
        }
        policy.updatePinch(magnification: 0.72)
        #expect(abs(policy.scale - 0.9090909090909091) < 1e-10)
    }

    @Test func releasePersistsEnlargedScaleAndNextPinchStartsFresh() {
        var policy = ReaderStickyBaselineZoomPolicy()
        policy.beginPinch()
        policy.updatePinch(magnification: 2)
        policy.endPinch()
        #expect(policy.scale == policy.committedScale)
        #expect(abs(policy.scale - 2) < 1e-10)
        #expect(!policy.isPinching)
        policy.beginPinch()
        policy.updatePinch(magnification: 0.5)
        #expect(policy.phase == .heldAtBaseline)
        #expect(policy.scale == 1)
        policy.endPinch()
        #expect(policy.committedScale == 1)
        #expect(!policy.isPinching)
    }

    @Test func releaseBelowBaselinePersistsAndNextPinchBypassesDetent() {
        var policy = ReaderStickyBaselineZoomPolicy()
        policy.beginPinch()
        policy.updatePinch(magnification: 0.9)
        policy.updatePinch(magnification: 0.72)
        policy.endPinch()
        #expect(abs(policy.committedScale - 0.9090909090909091) < 1e-10)
        policy.beginPinch()
        policy.updatePinch(magnification: 0.9)
        #expect(abs(policy.scale - 0.8181818181818182) < 1e-10)
        #expect(policy.phase == .crossedBelow)
    }

    @Test(arguments: [2.0, 0.75])
    func cancellationRestoresCommittedScale(committed: Double) {
        var policy = ReaderStickyBaselineZoomPolicy()
        policy.beginPinch()
        if committed > 1 {
            policy.updatePinch(magnification: committed)
        } else {
            policy.updatePinch(magnification: 0.5)
            policy.updatePinch(magnification: 0.1)
        }
        policy.endPinch()
        let before = policy
        policy.beginPinch()
        policy.updatePinch(magnification: committed > 1 ? 0.5 : 10)
        #expect(policy.scale != before.scale)
        policy.cancelPinch()
        #expect(policy == before)
    }

    @Test func resetClearsActiveAndCommittedPresentation() {
        var policy = ReaderStickyBaselineZoomPolicy()
        policy.beginPinch()
        policy.updatePinch(magnification: 2)
        policy.endPinch()
        policy.beginPinch()
        policy.updatePinch(magnification: 0.5)
        policy.reset()
        #expect(policy == ReaderStickyBaselineZoomPolicy())
    }

    @Test func inactiveUpdatesAndRepeatedLifecycleCallsAreHarmless() {
        var policy = ReaderStickyBaselineZoomPolicy()
        let initial = policy
        policy.updatePinch(magnification: 2)
        policy.endPinch()
        policy.cancelPinch()
        #expect(policy == initial)
        policy.beginPinch()
        policy.updatePinch(magnification: 2)
        let active = policy
        policy.beginPinch()
        #expect(policy == active)
    }

    @Test func extremeFiniteSamplesStayBoundedAndReverseImmediately() {
        var policy = ReaderStickyBaselineZoomPolicy()
        policy.beginPinch()
        policy.updatePinch(magnification: Double.greatestFiniteMagnitude)
        #expect(policy.scale == 3)
        policy.updatePinch(magnification: Double.leastNonzeroMagnitude)
        #expect(policy.scale == 1)
        policy.updatePinch(magnification: Double.leastNonzeroMagnitude * 2)
        #expect(abs(policy.scale - 2) < 1e-10)
        #expect(policy.phase == .tracking)
    }
}
