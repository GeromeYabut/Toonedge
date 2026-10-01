import Foundation
import ImageIO

public enum ReaderImageDecodeError: Error, Equatable {
    case invalidImage
}

public protocol ReaderImageDecoding: Sendable {
    func decode(_ data: Data) async throws -> ReaderDecodedImage
}

public struct ImageIOReaderImageDecoder: ReaderImageDecoding {
    public init() {}

    public func decode(_ data: Data) async throws -> ReaderDecodedImage {
        try await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw ReaderImageDecodeError.invalidImage
            }
            return ReaderDecodedImage(
                cgImage: image,
                pixelWidth: image.width,
                pixelHeight: image.height
            )
        }.value
    }
}
