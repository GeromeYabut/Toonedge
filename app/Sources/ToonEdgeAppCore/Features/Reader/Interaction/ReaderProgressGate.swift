import CoreGraphics
import Foundation

public struct ReaderProgressObservation: Equatable, Sendable {
    public let token: ReaderInteractionToken
    public let pipelineID: ObjectIdentifier
    public let pageIndex: Int
    public let pageFrame: CGRect
    public let targetAvailable: Bool
    public init(token: ReaderInteractionToken, pipelineID: ObjectIdentifier,
                pageIndex: Int, pageFrame: CGRect, targetAvailable: Bool) {
        self.token = token; self.pipelineID = pipelineID; self.pageIndex = pageIndex
        self.pageFrame = pageFrame; self.targetAvailable = targetAvailable
    }
}

public struct ReaderPageReadiness: Sendable {
    public let pipelineID: ObjectIdentifier
    public let pageIndex: Int
    public let image: ReaderDecodedImage
    public init(pipelineID: ObjectIdentifier, pageIndex: Int, image: ReaderDecodedImage) {
        self.pipelineID = pipelineID; self.pageIndex = pageIndex; self.image = image
    }
}

@MainActor
public final class ReaderProgressGate {
    public private(set) var coordinator: ReaderInteractionCoordinator
    private let session: MockReaderSession
    private let pipelineID: ObjectIdentifier
    private let readiness: @MainActor (Int) -> ReaderPageReadiness?
    private var observation: ReaderProgressObservation?
    private var latestOperationID: UUID?
    private var retired = false

    public init?(session: MockReaderSession, coordinator: ReaderInteractionCoordinator,
                 pipelineID: ObjectIdentifier,
                 readiness: @escaping @MainActor (Int) -> ReaderPageReadiness?) {
        guard session.id == coordinator.sessionID,
              session.imageURLs.count == coordinator.pageCount else { return nil }
        self.session = session; self.coordinator = coordinator
        self.pipelineID = pipelineID; self.readiness = readiness
    }

    /// The closure's event return is not inferred from this boundary; observe resulting state.
    public func transition(_ update: (inout ReaderInteractionCoordinator) -> Void) {
        guard !retired else { return }
        var candidate = coordinator
        update(&candidate)
        guard candidate.sessionID == coordinator.sessionID,
              candidate.installationID == coordinator.installationID,
              candidate.pageCount == coordinator.pageCount else { return }
        let oldReceipt = coordinator.baselineReceipt
        coordinator = candidate
        if candidate.baselineReceipt != oldReceipt || candidate.isSuspended ||
            candidate.activeGesture != nil || candidate.failure != nil {
            clearObservation()
        }
    }

    @discardableResult
    public func observe(_ candidate: ReaderProgressObservation) -> Bool {
        guard !retired, candidate.pipelineID == pipelineID,
              coordinator.baselineReceipt?.token == candidate.token,
              coordinator.baselineReceipt?.target.anchor.pageIndex == candidate.pageIndex,
              coordinator.isCurrent(candidate.token) else { return false }
        guard visibleDecodedTarget(candidate) else { clearObservation(); return false }
        if observation != candidate { latestOperationID = nil }
        observation = candidate
        return true
    }

    public func refreshReadiness() {
        if let observation, !visibleDecodedTarget(observation) { clearObservation() }
    }

    public func retireInstallation() {
        retired = true
        clearObservation()
    }

    public func admit(operationID: UUID, readAt: Date) -> ReaderAuthorizedReading? {
        guard eligible, let observation else { return nil }
        let label = ChapterNumericLabelExtractor.label(chapterNumber: nil,
            chapterLabel: "", title: session.chapterTitle)
            ?? ChapterNumericLabelExtractor.label(chapterNumber: nil,
                chapterLabel: "", title: session.sourceURL.path) ?? session.chapterTitle
        let input = RecentReadingInput(seriesID: session.seriesID, chapterID: session.id,
            seriesTitle: session.seriesTitle, seriesURL: session.seriesURL,
            sourceDomain: session.sourceDomain, coverImageURL: session.coverImageURL,
            chapterTitle: session.chapterTitle, chapterLabel: label, sourceURL: session.sourceURL,
            imageURLs: session.imageURLs,
            progress: ReaderProgress(currentImageIndex: observation.pageIndex,
                totalImageCount: session.imageURLs.count), readAt: readAt)
        latestOperationID = operationID
        let authorization = ReaderCommitAuthorization(operationID: operationID) { [weak self] effect in
            guard let self else { return false }
            guard self.eligible else { self.latestOperationID = nil; return false }
            return self.latestOperationID == operationID && Self.matches(effect, input: input)
        }
        return ReaderAuthorizedReading(input: input, authorization: authorization)
    }

    private var eligible: Bool {
        guard !retired, !coordinator.isSuspended, !coordinator.restoreWindowOpen,
              coordinator.activeGesture == nil, coordinator.failure == nil,
              let receipt = coordinator.baselineReceipt,
              coordinator.isCurrent(receipt.token), receipt.target.scale == 1,
              coordinator.confirmed?.scale == 1, coordinator.pendingApplicationRequest == nil,
              let observation, observation.token == receipt.token,
              observation.pageIndex == receipt.target.anchor.pageIndex else { return false }
        return visibleDecodedTarget(observation)
    }

    private func clearObservation() { observation = nil; latestOperationID = nil }

    private func visibleDecodedTarget(_ observation: ReaderProgressObservation) -> Bool {
        guard observation.targetAvailable, observation.pipelineID == pipelineID,
              let transform = coordinator.confirmed, transform.scale == 1,
              coordinator.layout?.geometry.revision == coordinator.latestRequestedRevision,
              !transform.layout.unresolvedPageIndexes.contains(observation.pageIndex),
              transform.layout.geometry.pageFrames.indices.contains(observation.pageIndex),
              let decoded = readiness(observation.pageIndex), decoded.pipelineID == pipelineID,
              decoded.pageIndex == observation.pageIndex,
              decoded.image.pixelWidth > 0, decoded.image.pixelHeight > 0,
              decoded.image.cgImage.width == decoded.image.pixelWidth,
              decoded.image.cgImage.height == decoded.image.pixelHeight,
              ReaderChapterGeometry.isUsable(observation.pageFrame) else { return false }
        let logical = transform.layout.geometry.pageFrames[observation.pageIndex]
        let decodedHeight = logical.width * CGFloat(decoded.image.pixelHeight)
            / CGFloat(decoded.image.pixelWidth)
        guard decodedHeight.isFinite, abs(decodedHeight - logical.height) <= 2 else { return false }
        let expected = CGRect(x: logical.minX + transform.translation.x,
            y: logical.minY + transform.translation.y, width: logical.width, height: logical.height)
        let actual = observation.pageFrame
        guard abs(actual.minX - expected.minX) <= 2,
              abs(actual.minY - expected.minY) <= 2,
              abs(actual.width - expected.width) <= 2,
              abs(actual.height - expected.height) <= 2 else { return false }
        let viewport = CGRect(origin: .zero, size: transform.layout.viewportSize)
        let intersection = actual.intersection(viewport)
        return !intersection.isNull && intersection.width > 0 && intersection.height > 0
    }

    private static func matches(_ effect: ReaderReadingEffect, input: RecentReadingInput) -> Bool {
        switch effect {
        case let .progress(progress, sourceURL, date):
            return progress == input.progress && sourceURL == input.sourceURL && date == input.readAt
        case let .recentReading(recent):
            return recent.seriesID == input.seriesID && recent.chapterID == input.chapterID &&
                recent.seriesURL == input.seriesURL && recent.sourceURL == input.sourceURL &&
                recent.sourceDomain == input.sourceDomain && recent.chapterTitle == input.chapterTitle &&
                recent.chapterLabel == input.chapterLabel && recent.imageURLs == input.imageURLs &&
                recent.progress == input.progress && recent.readAt == input.readAt
        case let .recentCache(cache):
            return cache.sourceURL == input.sourceURL && cache.chapterTitle == input.chapterTitle &&
                cache.chapterLabel == input.chapterLabel && cache.imageCount == input.imageURLs.count &&
                cache.retentionState == .recent && cache.estimatedStorageBytes == 0 &&
                cache.cachedAt == input.readAt
        }
    }
}
