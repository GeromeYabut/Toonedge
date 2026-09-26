import Foundation

public struct FileBackedChapterAssetCache: ChapterAssetCaching {
    public let rootDirectory: URL

    public init(rootDirectory: URL) throws {
        self.rootDirectory = rootDirectory
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    public func chapterDirectory(for sourceURL: URL) -> URL {
        rootDirectory.appendingPathComponent(namespace(for: sourceURL), isDirectory: true)
    }

    public func cachedAssetURL(for assetURL: URL, sourceURL: URL) -> URL? {
        let fileURL = chapterDirectory(for: sourceURL).appendingPathComponent(assetFilename(for: assetURL))
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    public func intendedAssetURL(for assetURL: URL, sourceURL: URL) -> URL {
        chapterDirectory(for: sourceURL).appendingPathComponent(assetFilename(for: assetURL))
    }

    public func store(_ data: Data, for assetURL: URL, sourceURL: URL) throws {
        let destination = intendedAssetURL(for: assetURL, sourceURL: sourceURL)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: .atomic)
    }

    public static func stableIdentifier(for value: String) -> String {
        var hash: UInt64 = 5_381
        for byte in value.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }

    private func namespace(for sourceURL: URL) -> String {
        let host = sanitized(sourceURL.host() ?? "source")
        let path = sanitized(sourceURL.pathComponents.suffix(2).joined(separator: "-"))
        let hash = Self.stableIdentifier(for: sourceURL.absoluteString)
        return [host, path, hash]
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private func assetFilename(for assetURL: URL) -> String {
        let extensionValue = assetURL.pathExtension.isEmpty ? "asset" : assetURL.pathExtension
        return "\(Self.stableIdentifier(for: assetURL.absoluteString)).\(sanitized(extensionValue))"
    }

    private func sanitized(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return String(
            value.unicodeScalars.map { scalar in
                allowed.contains(scalar) ? Character(scalar) : "-"
            }
        )
        .trimmingCharacters(in: CharacterSet(charactersIn: "-."))
    }
}
