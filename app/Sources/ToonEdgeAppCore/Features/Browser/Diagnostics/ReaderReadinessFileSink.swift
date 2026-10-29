import Foundation
import Darwin

/// Opt-in debug export of the finite readiness wire schema, never arbitrary payloads.
final class ReaderReadinessFileSink: @unchecked Sendable {
    #if DEBUG
    // A separate nonisolated constant avoids crossing the diagnostics MainActor.
    private static let wirePrefix = "TOONEDGE_READINESS_V1 "
    private static let directoryName = "ToonEdgeReadinessDiagnostics"
    private let lock = NSLock()
    private let rootFD: Int32
    private let directoryFD: Int32
    private var fileFD: Int32
    private let rootPath: String
    private let fileName: String
    private let rootIdentity: stat
    private let directoryIdentity: stat
    private let fileIdentity: stat
    private var records = 0
    private var bytes = 0

    private init(rootFD: Int32, directoryFD: Int32, fileFD: Int32,
                 rootPath: String, fileName: String, rootIdentity: stat,
                 directoryIdentity: stat, fileIdentity: stat) {
        self.rootFD = rootFD
        self.directoryFD = directoryFD
        self.fileFD = fileFD
        self.rootPath = rootPath
        self.fileName = fileName
        self.rootIdentity = rootIdentity
        self.directoryIdentity = directoryIdentity
        self.fileIdentity = fileIdentity
    }
    #else
    private init() {}
    #endif

    static func make(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        cachesRoot: URL? = nil,
        debugBuild: Bool = _isDebugAssertConfiguration()
    ) -> ReaderReadinessFileSink? {
        #if DEBUG
        // Reject before resolving or touching caches in ordinary/default launches.
        let nonceIndices = arguments.indices.filter { arguments[$0] == "-readerReadinessRunID" }
        guard debugBuild,
              arguments.filter({ $0 == "-readerReadinessDiagnostics" }).count == 1,
              nonceIndices.count == 1, let index = nonceIndices.first,
              index + 1 < arguments.count else { return nil }
        let token = arguments[index + 1]
        guard token.utf8.count == 36, let uuid = UUID(uuidString: token),
              uuid.uuidString == token else { return nil }
        guard let requestedRoot = cachesRoot ?? FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask).first,
              requestedRoot.isFileURL else { return nil }
        // System aliases at the trusted starting root are legitimate. Every open
        // below this physical root is relative to a verified descriptor, no-follow.
        let physicalRoot = requestedRoot.standardizedFileURL.resolvingSymlinksInPath()
        let rootPath = physicalRoot.path
        let rootFD = rootPath.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard rootFD >= 0 else { return nil }
        var transferRoot = false
        defer { if !transferRoot { Darwin.close(rootFD) } }
        var rootInfo = stat()
        var rootPathInfo = stat()
        guard Darwin.fstat(rootFD, &rootInfo) == 0,
              Darwin.lstat(rootPath, &rootPathInfo) == 0,
              isDirectory(rootInfo), rootInfo.st_uid == Darwin.getuid(),
              sameIdentity(rootInfo, rootPathInfo) else { return nil }

        let created = Darwin.mkdirat(rootFD, directoryName, mode_t(0o700)) == 0
        guard created || errno == EEXIST else { return nil }
        let directoryFD = directoryName.withCString {
            Darwin.openat(rootFD, $0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard directoryFD >= 0 else { return nil }
        var transferDirectory = false
        defer { if !transferDirectory { Darwin.close(directoryFD) } }
        var directoryInfo = stat()
        guard Darwin.fstat(directoryFD, &directoryInfo) == 0,
              isDirectory(directoryInfo), directoryInfo.st_uid == Darwin.getuid() else { return nil }
        // Accept only an already-private directory. A restrictive umask may make
        // creation fail closed; never repair or broaden any directory permissions.
        guard directoryInfo.st_mode & mode_t(0o777) == mode_t(0o700),
              directoryIsLinked(rootFD: rootFD, directoryInfo: directoryInfo) else { return nil }

        let fileName = token + ".jsonl"
        let fileFD = fileName.withCString {
            Darwin.openat(directoryFD, $0,
                O_WRONLY | O_APPEND | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600))
        }
        guard fileFD >= 0 else { return nil }
        var transferFile = false
        defer { if !transferFile { Darwin.close(fileFD) } }
        var fileInfo = stat()
        guard Darwin.fchmod(fileFD, mode_t(0o600)) == 0,
              Darwin.fstat(fileFD, &fileInfo) == 0,
              isPrivateFile(fileInfo), fileInfo.st_size == 0 else { return nil }
        let sink = ReaderReadinessFileSink(rootFD: rootFD, directoryFD: directoryFD,
            fileFD: fileFD, rootPath: rootPath, fileName: fileName,
            rootIdentity: rootInfo, directoryIdentity: directoryInfo, fileIdentity: fileInfo)
        transferRoot = true
        transferDirectory = true
        transferFile = true
        guard sink.hasExpectedIdentity(size: 0) else { return nil }
        return sink
        #else
        return nil
        #endif
    }

    /// Synchronously append only canonical finite-schema JSON plus one LF.
    @discardableResult
    func write(_ line: String) -> Bool {
        #if DEBUG
        return lock.withLock {
            guard fileFD >= 0, records < 128,
                  let data = Self.validatedPayload(line),
                  data.count <= 4_096, bytes + data.count <= 512 * 1_024 else { return false }
            guard hasExpectedIdentity(size: bytes) else {
                stopWriting()
                return false
            }
            let written = data.withUnsafeBytes { buffer in
                Darwin.write(fileFD, buffer.baseAddress, buffer.count)
            }
            guard written == data.count, hasExpectedIdentity(size: bytes + data.count) else {
                // Preserve earlier complete records when a local write is short.
                // The descriptor refers only to this invocation's exclusive file.
                _ = Darwin.ftruncate(fileFD, off_t(bytes))
                stopWriting()
                return false
            }
            records += 1
            bytes += data.count
            return true
        }
        #else
        return false
        #endif
    }

    #if DEBUG
    private static func validatedPayload(_ line: String) -> Data? {
        guard line.utf8.count <= 4_096, line.hasPrefix(wirePrefix), line.hasSuffix("\n") else { return nil }
        let payload = Data(line.dropFirst(wirePrefix.count).dropLast().utf8)
        guard var event = try? JSONDecoder().decode(ReaderReadinessEvent.self, from: payload),
              event.schema == 1, (1...1_000_000).contains(event.navigation),
              (0..<60_000).contains(event.elapsedMs),
              (0...6).contains(event.attempt),
              event.analysis == .recovery ? (1...4).contains(event.attempt) : event.attempt == 0,
              (0...1_000_000).contains(event.rawImages),
              (0...1_000_000).contains(event.evidenceImages),
              (0...1_000_000).contains(event.candidates),
              (-10_000...10_000).contains(event.score),
              event.httpStatus == 0 || (100...599).contains(event.httpStatus),
              event.hardBlocks.count <= DetectionHardBlock.allCases.count else { return nil }
        event.hardBlocks = Array(Set(event.hardBlocks)).sorted { $0.rawValue < $1.rawValue }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Exact re-encoding rejects unknown/missing/duplicate fields, alternate
        // encodings and whitespace. Codable enums reject all arbitrary strings.
        guard var canonical = try? encoder.encode(event), canonical == payload else { return nil }
        canonical.append(10)
        return canonical
    }

    private static func sameIdentity(_ a: stat, _ b: stat) -> Bool {
        a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_uid == b.st_uid
            && (a.st_mode & mode_t(S_IFMT)) == (b.st_mode & mode_t(S_IFMT))
    }

    private static func isDirectory(_ info: stat) -> Bool {
        info.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR)
    }

    private static func isPrivateFile(_ info: stat) -> Bool {
        info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG)
            && info.st_mode & mode_t(0o777) == mode_t(0o600)
            && info.st_uid == Darwin.getuid() && info.st_nlink == 1
    }

    private static func directoryIsLinked(rootFD: Int32, directoryInfo: stat) -> Bool {
        var linked = stat()
        return Darwin.fstatat(rootFD, directoryName, &linked, AT_SYMLINK_NOFOLLOW) == 0
            && isDirectory(linked) && sameIdentity(linked, directoryInfo)
    }

    private func hasExpectedIdentity(size: Int) -> Bool {
        var rootInfo = stat()
        var pathInfo = stat()
        var directoryInfo = stat()
        var fileInfo = stat()
        var linkedFile = stat()
        guard fileFD >= 0,
              Darwin.fstat(rootFD, &rootInfo) == 0,
              Darwin.lstat(rootPath, &pathInfo) == 0,
              Self.isDirectory(rootInfo), Self.isDirectory(pathInfo),
              Self.sameIdentity(rootInfo, rootIdentity), Self.sameIdentity(pathInfo, rootIdentity),
              Darwin.fstat(directoryFD, &directoryInfo) == 0,
              Self.sameIdentity(directoryInfo, directoryIdentity),
              directoryInfo.st_mode & mode_t(0o777) == mode_t(0o700),
              Self.directoryIsLinked(rootFD: rootFD, directoryInfo: directoryIdentity),
              Darwin.fstat(fileFD, &fileInfo) == 0,
              Darwin.fstatat(directoryFD, fileName, &linkedFile, AT_SYMLINK_NOFOLLOW) == 0,
              Self.isPrivateFile(fileInfo), Self.isPrivateFile(linkedFile),
              Self.sameIdentity(fileInfo, fileIdentity), Self.sameIdentity(linkedFile, fileIdentity),
              fileInfo.st_size == off_t(size) else { return false }
        return true
    }

    private func stopWriting() {
        if fileFD >= 0 { Darwin.close(fileFD); fileFD = -1 }
    }

    deinit {
        if fileFD >= 0 { Darwin.close(fileFD) }
        Darwin.close(directoryFD)
        Darwin.close(rootFD)
    }
    #endif
}
