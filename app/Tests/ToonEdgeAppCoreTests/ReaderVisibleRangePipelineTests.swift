import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore

struct ReaderVisibleRangePipelineTests {
    @Test @MainActor func allVisibleShortPagesLoadAndRetryBeyondOldWindowWithoutExceedingThree() async throws {
        let urls = (0..<20).map { URL(string: "https://owned.test/page-\($0).png")! }
        let session = MockReaderSession(seriesTitle: "Owned", chapterTitle: "Chapter 1",
            sourceURL: URL(string: "https://owned.test/chapter-1")!, imageURLs: urls)
        let loader = VisibleRangeOwnedLoader()
        let pipeline = ReaderPagePipeline(session: session, assetLoader: loader, decoder: VisibleRangeOwnedDecoder())
        pipeline.updateVisibleIndexes(Array(1...7), loadingAnchorIndex: 1)
        var failure: Error?
        do {
            try await wait { (1...7).allSatisfy { pipeline.states[$0]?.status == ($0 == 5 ? .failed : .ready) } }
            let peak = await loader.peak
            #expect(peak <= 3)
            let requested = await loader.requested
            #expect(Set(requested).isSubset(of: Set(0...9)))
            #expect(Set(requested).isSuperset(of: Set(1...7)))
            pipeline.retry(index: 5)
            try await wait { pipeline.states[5]?.status == .ready }
            pipeline.handleMemoryPressure()
            try await wait { (1...7).allSatisfy { pipeline.states[$0]?.status == .ready } }
        } catch { failure = error }
        pipeline.cancel()
        let drained = await pipeline.waitForWorkToDrain()
        #expect(drained)
        if let failure { throw failure }
    }
    @MainActor private func wait(_ predicate: () -> Bool) async throws {
        let end = ContinuousClock.now.advanced(by: .seconds(5))
        while !predicate() {
            guard ContinuousClock.now < end else { throw VisibleRangeTimeout.expired }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
private enum VisibleRangeTimeout: Error { case expired }
private actor VisibleRangeOwnedLoader: ReaderPageAssetLoading {
    private var active = 0
    private(set) var peak = 0
    private(set) var requested: [Int] = []
    private var failedOnce = false
    func load(imageURL: URL, sourceURL: URL, requestContext: ReaderImageRequestContext?) async throws -> Data {
        let index = Int(imageURL.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "page-", with: ""))!
        requested.append(index)
        active += 1; peak = max(peak, active)
        defer { active -= 1 }
        try await Task.sleep(for: .milliseconds(30))
        if index == 5 && !failedOnce { failedOnce = true; throw ReaderPageFailure.decode }
        return Data([1])
    }
}
private struct VisibleRangeOwnedDecoder: ReaderImageDecoding {
    func decode(_ data: Data) async throws -> ReaderDecodedImage {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8,
            bytesPerRow: 8, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let image = context.makeImage()!
        return ReaderDecodedImage(cgImage: image, pixelWidth: 2, pixelHeight: 2)
    }
}
