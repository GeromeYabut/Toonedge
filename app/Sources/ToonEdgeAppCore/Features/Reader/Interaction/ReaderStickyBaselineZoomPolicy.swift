import Foundation

/// Scale policy only. Baseline scale never grants scrolling or progress permission.
public struct ReaderStickyBaselineZoomPolicy: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case tracking, heldAtBaseline, crossedBelow
    }

    public static let minimumScale = 0.75
    public static let maximumScale = 3.0
    public static let snapEntryScale = 1.03
    public static let breakthroughRatio = 0.88

    public private(set) var scale = 1.0
    public private(set) var committedScale = 1.0
    public private(set) var isPinching = false
    public private(set) var phase: Phase = .tracking

    private var previousMagnification = 1.0
    private var heldLogDistance = 0.0
    private static let equalityTolerance = 1e-12

    public init() {}

    public mutating func beginPinch() {
        guard !isPinching else { return }
        isPinching = true
        clearGesture()
    }

    public mutating func updatePinch(magnification: Double) {
        guard isPinching, magnification.isFinite, magnification > 0,
              magnification != previousMagnification else { return }
        let delta = log(magnification) - log(previousMagnification)
        previousMagnification = magnification
        guard delta != 0 else { return }

        if phase == .heldAtBaseline {
            if delta < 0 {
                heldLogDistance -= delta
                let threshold = -log(Self.breakthroughRatio)
                guard heldLogDistance >= threshold - Self.equalityTolerance else { return }
                let excess = max(0, heldLogDistance - threshold)
                scale = Self.boundedScale(logScale: excess <= Self.equalityTolerance ? 0 : -excess)
                phase = .crossedBelow
                heldLogDistance = 0
                return
            }
            phase = .tracking
            heldLogDistance = 0
        }

        let nextLogScale = log(scale) + delta
        if delta < 0, phase == .tracking, scale >= 1,
           nextLogScale <= log(Self.snapEntryScale) {
            scale = 1
            phase = .heldAtBaseline
            heldLogDistance = 0
            return
        }
        scale = Self.boundedScale(logScale: nextLogScale)
        if delta > 0, scale >= 1 { phase = .tracking }
    }

    public mutating func endPinch() {
        guard isPinching else { return }
        committedScale = scale
        isPinching = false
        clearGesture()
    }

    public mutating func cancelPinch() {
        guard isPinching else { return }
        scale = committedScale
        isPinching = false
        clearGesture()
    }

    public mutating func reset() {
        self = Self()
    }

    private mutating func clearGesture() {
        previousMagnification = 1
        heldLogDistance = 0
        phase = scale < 1 ? .crossedBelow : .tracking
    }

    private static func boundedScale(logScale: Double) -> Double {
        if logScale <= log(minimumScale) { return minimumScale }
        if logScale >= log(maximumScale) { return maximumScale }
        return exp(logScale)
    }
}
