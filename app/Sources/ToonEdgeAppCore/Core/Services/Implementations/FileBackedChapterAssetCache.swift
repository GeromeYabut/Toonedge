import Foundation

public struct FileBackedChapterAssetCache: ChapterAssetCaching, ChapterAssetRemoving {
    public let rootDirectory: URL
    private let fileManager: FileManager & Sendable
    // A reference shared by value-type copies injected into Reader, retention and removal.
    // A store owns the lock through directory creation AND atomic write, so removal
    // cannot finish while that store can still recreate its chapter directory.
    private let lifecycleLock = NSLock()

    public init(rootDirectory: URL) throws {
        try self.init(rootDirectory: rootDirectory, fileManager: CacheFileManager())
    }

    init(rootDirectory: URL, fileManager: FileManager & Sendable) throws {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    public func chapterDirectory(for sourceURL: URL) -> URL {
        rootDirectory.appendingPathComponent(namespace(for: sourceURL), isDirectory: true)
    }

    public func cachedAssetURL(for assetURL: URL, sourceURL: URL) -> URL? {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        let fileURL = chapterDirectory(for: sourceURL).appendingPathComponent(assetFilename(for: assetURL))
        return fileManager.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    public func intendedAssetURL(for assetURL: URL, sourceURL: URL) -> URL {
        chapterDirectory(for: sourceURL).appendingPathComponent(assetFilename(for: assetURL))
    }

    public func store(_ data: Data, for assetURL: URL, sourceURL: URL) throws {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        let destination = intendedAssetURL(for: assetURL, sourceURL: sourceURL)
        try fileManager.createDirectory(
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

    public func removeAssets(for sourceURL: URL) throws {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        do {
            try fileManager.removeItem(at: chapterDirectory(for: sourceURL))
        } catch CocoaError.fileNoSuchFile {
            // Metadata-only entries and retries after metadata failures are safe to remove.
        }
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

// Only FileManager's thread-safe file operations are used; no delegate or mutable configuration.
private final class CacheFileManager: FileManager, @unchecked Sendable {}
