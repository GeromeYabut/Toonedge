import Foundation

// Safe diagnostic values carry no source identity or arbitrary text.
public enum ReaderImagePreflightOutcome: String, Codable, Equatable, Sendable {
    case none, noImage, transportError, httpFailure, emptyData, unrecognizedImage, recognizedImage
}

public enum ReaderReadinessTransport: String, Codable, Equatable, Sendable {
    case none, timedOut, cancelled, offline, dns, connection, tls, other
}

public enum ReaderReadinessPixelBucket: String, Codable, Equatable, Sendable {
    case unknown, zero, small, medium, large, giant
}

public struct ReaderImagePreflightObservation: Equatable, Sendable {
    public let outcome: ReaderImagePreflightOutcome
    public let httpStatus: Int
    public let transport: ReaderReadinessTransport
    public let pixelWidth: ReaderReadinessPixelBucket
    public let pixelHeight: ReaderReadinessPixelBucket

    public init(outcome: ReaderImagePreflightOutcome, httpStatus: Int = 0,
                transport: ReaderReadinessTransport = .none,
                pixelWidth: ReaderReadinessPixelBucket = .unknown,
                pixelHeight: ReaderReadinessPixelBucket = .unknown) {
        self.outcome = outcome
        self.httpStatus = httpStatus
        self.transport = transport
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

enum ReaderReadinessStage: String, Codable, Sendable {
    case navigationStarted, navigationFinished, navigationFailed
    case analysisStarted, analysisCompleted, analysisFailed
    case preflightStarted, preflightCompleted, handoff, guardStopped, recoveryStopped
}

enum ReaderReadinessAnalysis: String, Codable, Sendable {
    case none, initial, followUp, recovery
}

enum ReaderReadinessParser: String, Codable, Sendable {
    case none, siteProfile, genericHeuristic, browserSessionProfile
    case browserOnlyProfile, unsupportedPaginatedProfile
}

enum ReaderReadinessDisposition: String, Codable, Sendable {
    case none, automatic, recommended, manual, unavailable
}

enum ReaderReadinessStop: String, Codable, Sendable {
    case none, unavailable, hardBlock, missingSession, sourceMismatch, noImages
    case staleDocument, viableResult, recoveryDeadline, attemptLimit, cancelled
    case teardown, navigationChanged, analysisFailure, unreadableImage
}

struct ReaderReadinessEvent: Codable, Sendable {
    var schema = 1
    var navigation: Int
    var elapsedMs: Int
    var stage: ReaderReadinessStage
    var analysis: ReaderReadinessAnalysis = .none
    var attempt = 0
    var rawImages = 0
    var evidenceImages = 0
    var candidates = 0
    var parser: ReaderReadinessParser = .none
    var score = 0
    var disposition: ReaderReadinessDisposition = .none
    var hardBlocks: [DetectionHardBlock] = []
    var preflight: ReaderImagePreflightOutcome = .none
    var httpStatus = 0
    var transport: ReaderReadinessTransport = .none
    var pixelWidth: ReaderReadinessPixelBucket = .unknown
    var pixelHeight: ReaderReadinessPixelBucket = .unknown
    var stop: ReaderReadinessStop = .none
}

extension ReaderReadinessTransport {
    static func category(for error: any Error) -> Self {
        guard let error = error as? URLError else { return .other }
        switch error.code {
        case .timedOut: return .timedOut
        case .cancelled: return .cancelled
        case .notConnectedToInternet, .networkConnectionLost: return .offline
        case .cannotFindHost, .dnsLookupFailed: return .dns
        case .cannotConnectToHost: return .connection
        case .secureConnectionFailed, .serverCertificateHasBadDate,
             .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid, .clientCertificateRejected,
             .clientCertificateRequired: return .tls
        default: return .other
        }
    }
}

extension ReaderReadinessPixelBucket {
    static func classify(_ property: Any?) -> Self {
        guard let number = property as? NSNumber else { return .unknown }
        let value = number.doubleValue
        guard value.isFinite, value >= 0, value.rounded(.towardZero) == value else { return .unknown }
        switch value {
        case 0: return .zero
        case ..<320: return .small
        case ..<1024: return .medium
        case ..<4096: return .large
        default: return .giant
        }
    }
}

extension ReaderImagePreflightObservation {
    static func safeStatus(_ status: Int) -> Int { (100...599).contains(status) ? status : 0 }
}

// The callback is synchronous and may run off the coordinator's actor. Only its
// finite observation crosses that boundary; no request, response or error is held.
final class ReaderPreflightObservationBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var observation: ReaderImagePreflightObservation?
    func record(_ observation: ReaderImagePreflightObservation) {
        lock.withLock { self.observation = observation }
    }
    func read() -> ReaderImagePreflightObservation? { lock.withLock { observation } }
}

@MainActor
final class ReaderReadinessDiagnostics {
    static let wirePrefix = "TOONEDGE_READINESS_V1 "
    static let shared: ReaderReadinessDiagnostics = {
        #if DEBUG
        let fileSink = ReaderReadinessFileSink.make()
        return ReaderReadinessDiagnostics(
            enabled: isEnabled(arguments: ProcessInfo.processInfo.arguments, debugBuild: true),
            lineWriter: { line in
                try? FileHandle.standardOutput.write(contentsOf: Data(line.utf8))
                _ = fileSink?.write(line)
            })
        #else
        return ReaderReadinessDiagnostics()
        #endif
    }()

    private let enabled: Bool
    private let now: @Sendable () -> TimeInterval
    private let lineWriter: @Sendable (String) -> Void
    private var navigation = 0
    private var startedAt: TimeInterval?
    private var navigationEvents = 0
    private var runEvents = 0
    private var runBytes = 0
    private var lastElapsedMs = -1

    init(enabled: Bool = false,
         now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         lineWriter: @escaping @Sendable (String) -> Void = { _ in }) {
        #if DEBUG
        self.enabled = enabled
        #else
        self.enabled = false
        #endif
        self.now = now
        self.lineWriter = lineWriter
    }

    static func isEnabled(arguments: [String], debugBuild: Bool) -> Bool {
        debugBuild && arguments.contains("-readerReadinessDiagnostics")
    }

    func startNavigation() -> Int {
        guard enabled, navigation < 1_000_000 else { return 0 }
        let time = now()
        guard time.isFinite else { return 0 }
        navigation += 1
        startedAt = time
        navigationEvents = 0
        lastElapsedMs = -1
        return navigation
    }

    func elapsedMilliseconds(for navigation: Int) -> Int? {
        guard enabled, navigation > 0, navigation == self.navigation, let startedAt else { return nil }
        let elapsed = now() - startedAt
        guard elapsed.isFinite, elapsed >= 0, elapsed < 60 else { return nil }
        return Int(elapsed * 1_000)
    }

    @discardableResult
    func emit(_ event: ReaderReadinessEvent) -> Bool {
        guard let elapsedNow = elapsedMilliseconds(for: event.navigation),
              event.schema == 1, (1...1_000_000).contains(event.navigation),
              (0..<60_000).contains(event.elapsedMs), event.elapsedMs <= elapsedNow,
              event.elapsedMs >= lastElapsedMs,
              (0...6).contains(event.attempt),
              event.analysis == .recovery ? (1...4).contains(event.attempt) : event.attempt == 0,
              (0...1_000_000).contains(event.rawImages),
              (0...1_000_000).contains(event.evidenceImages),
              (0...1_000_000).contains(event.candidates),
              (-10_000...10_000).contains(event.score),
              event.httpStatus == 0 || (100...599).contains(event.httpStatus),
              event.hardBlocks.count <= DetectionHardBlock.allCases.count,
              navigationEvents < 64, runEvents < 128 else { return false }
        var safe = event
        safe.hardBlocks = Array(Set(event.hardBlocks)).sorted { $0.rawValue < $1.rawValue }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(safe), let json = String(data: data, encoding: .utf8) else { return false }
        let line = Self.wirePrefix + json + "\n"
        let byteCount = line.utf8.count
        guard byteCount <= 4_096, runBytes + byteCount <= 512 * 1_024 else { return false }
        navigationEvents += 1
        runEvents += 1
        runBytes += byteCount
        lastElapsedMs = event.elapsedMs
        lineWriter(line)
        return true
    }

    // Supplemental metadata only, never an alternate detector or policy input.
    static func evidenceImageCount(in page: DetectionPageAnalysis) -> Int {
        let count = page.images.lazy.filter { image in
            guard image.width.isFinite, image.height.isFinite,
                  image.width >= 0, image.height >= 0 else { return false }
            if image.width >= 320 && image.height >= 500 { return true }
            let hints = image.semanticHints.map { $0.lowercased() }
            guard hints.contains("data-reader-page-image") else { return false }
            let context = [image.alt, image.className, image.parentSignature]
                .compactMap { $0 }.joined(separator: " ").lowercased()
            return hints.contains("data-reader-index") || context.contains("chapter")
                || context.contains("page") || context.contains("reader")
        }.count
        return min(1_000_000, count)
    }
}
