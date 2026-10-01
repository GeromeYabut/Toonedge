import Foundation
import ImageIO

public enum ReaderImageDecodeError: Error, Equatable {
    case invalidImage
}

public protocol ReaderImageDecoding: Sendable {
    func decode(_ data: Data) async throws -> ReaderDecodedImage
}

public struct ImageIOReaderImageDecoder: ReaderImageDecoding {
    private let beforeReturning: @Sendable () async -> Void

    public init() {
        self.beforeReturning = {}
    }

    init(beforeReturning: @escaping @Sendable () async -> Void) {
        self.beforeReturning = beforeReturning
    }

    public func decode(_ data: Data) async throws -> ReaderDecodedImage {
        try Task.checkCancellation()

        let decodingTask = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let options: CFDictionary = [
                kCGImageSourceShouldCache: true,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, options) else {
                throw ReaderImageDecodeError.invalidImage
            }
            try Task.checkCancellation()
            return ReaderDecodedImage(
                cgImage: image,
                pixelWidth: image.width,
                pixelHeight: image.height
            )
        }

        return try await withTaskCancellationHandler {
            let image = try await decodingTask.value
            await beforeReturning()
            try Task.checkCancellation()
            return image
        } onCancel: {
            decodingTask.cancel()
        }
    }
}
