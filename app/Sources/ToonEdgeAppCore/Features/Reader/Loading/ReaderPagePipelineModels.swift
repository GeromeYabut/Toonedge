import CoreGraphics
import Foundation

public enum ReaderPageStatus: Equatable, Sendable {
    case idle
    case queued
    case loading
    case ready
    case failed
}

public struct ReaderDecodedImage: @unchecked Sendable {
    public let cgImage: CGImage
    public let pixelWidth: Int
    public let pixelHeight: Int
}

public struct ReaderPageState: Sendable {
    public var status: ReaderPageStatus
    public var image: ReaderDecodedImage?
    public var failure: ReaderPageFailure?
    public var learnedMetadata: ReaderPageMetadata?

    public init(
        status: ReaderPageStatus,
        image: ReaderDecodedImage?,
        failure: ReaderPageFailure?,
        learnedMetadata: ReaderPageMetadata? = nil
    ) {
        self.status = status
        self.image = image
        self.failure = failure
        self.learnedMetadata = learnedMetadata
    }
}

public enum ReaderPageFailure: String, Error, Equatable, Sendable {
    case network
    case invalidResponse
    case emptyData
    case decode
}

public struct ReaderPrefetchPolicy: Equatable, Sendable {
    public let behind: Int
    public let ahead: Int
    public let maximumConcurrentLoads: Int

    public init(behind: Int, ahead: Int, maximumConcurrentLoads: Int) {
        self.behind = behind
        self.ahead = ahead
        self.maximumConcurrentLoads = maximumConcurrentLoads
    }

    public func targetIndexes(current: Int, pageCount: Int) -> [Int] {
        guard pageCount > 0 else { return [] }

        let current = min(max(0, current), pageCount - 1)
        let forward = (current...min(pageCount - 1, current + ahead)).map { $0 }
        let backward = stride(from: current - 1, through: max(0, current - behind), by: -1).map { $0 }
        return forward + backward
    }
}
