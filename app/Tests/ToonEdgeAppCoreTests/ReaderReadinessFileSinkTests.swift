import Foundation
import Testing
@testable import ToonEdgeAppCore

private struct ReadinessFileFixture {
    let root: URL
    let caches: URL
    let runID = "A53B3C71-47A6-4AAE-82E4-6B2DDF6411AC"

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("toonedge-readiness-unit-" + UUID().uuidString, isDirectory: true)
            .resolvingSymlinksInPath()
        caches = root.appendingPathComponent("Caches", isDirectory: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
    }

    var arguments: [String] {
        ["app", "-readerReadinessDiagnostics", "-readerReadinessRunID", runID]
    }
    var directory: URL { caches.appendingPathComponent("ToonEdgeReadinessDiagnostics", isDirectory: true) }
    var file: URL { directory.appendingPathComponent(runID + ".jsonl") }
    func cleanup() { try? FileManager.default.removeItem(at: root) }
    func cacheEntries() throws -> [String] { try FileManager.default.contentsOfDirectory(atPath: caches.path) }
}

@Suite(.serialized)
@MainActor
struct ReaderReadinessFileSinkTests {
    private func wire(_ event: ReaderReadinessEvent? = nil) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let value = event ?? ReaderReadinessEvent(navigation: 1, elapsedMs: 0, stage: .navigationStarted)
        return ReaderReadinessDiagnostics.wirePrefix + String(decoding: try encoder.encode(value), as: UTF8.self) + "\n"
    }

    private func wireObject(_ object: [String: Any]) throws -> String {
        ReaderReadinessDiagnostics.wirePrefix
            + String(decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), as: UTF8.self) + "\n"
    }

    private func payload(_ line: String) -> String {
        String(line.dropFirst(ReaderReadinessDiagnostics.wirePrefix.count))
    }

    @Test func disabledAndReleaseConfigurationsCreateNothing() throws {
        let fixture = try ReadinessFileFixture()
        defer { fixture.cleanup() }
        let scenarios: [([String], Bool)] = [
            ([], true),
            (["app", "-readerReadinessRunID", fixture.runID], true),
            (["app", "-readerReadinessDiagnosticsExtra", "-readerReadinessRunID", fixture.runID], true),
            (["app", "readerReadinessDiagnostics", "-readerReadinessRunID", fixture.runID], true),
            (fixture.arguments, false)
        ]
        for (arguments, debugBuild) in scenarios {
            #expect(ReaderReadinessFileSink.make(arguments: arguments, cachesRoot: fixture.caches,
                debugBuild: debugBuild) == nil)
        }
        #expect(try fixture.cacheEntries().isEmpty)
    }

    @Test func invalidMissingOrDuplicateNoncesCreateNothing() throws {
        let fixture = try ReadinessFileFixture()
        defer { fixture.cleanup() }
        let prefix = ["app", "-readerReadinessDiagnostics"]
        let scenarios = [
            prefix,
            prefix + ["-readerReadinessRunID"],
            prefix + ["-readerReadinessRunID", ""],
            prefix + ["-readerReadinessRunID", fixture.runID.lowercased()],
            prefix + ["-readerReadinessRunID", "../" + fixture.runID],
            prefix + ["-readerReadinessRunID", "/" + fixture.runID],
            prefix + ["-readerReadinessRunID", fixture.runID + ".jsonl"],
            prefix + ["-readerReadinessRunID", "not-a-uuid"],
            prefix + ["-readerReadinessRunID=" + fixture.runID],
            prefix + ["-readerReadinessRunIDExtra", fixture.runID],
            fixture.arguments + ["-readerReadinessRunID", fixture.runID],
            fixture.arguments + ["-readerReadinessRunID", "B53B3C71-47A6-4AAE-82E4-6B2DDF6411AC"]
        ]
        for arguments in scenarios {
            #expect(ReaderReadinessFileSink.make(arguments: arguments, cachesRoot: fixture.caches,
                debugBuild: true) == nil)
        }
        #expect(try fixture.cacheEntries().isEmpty)
    }

    @Test func occupiedDestinationIsNeverTruncatedOrReplaced() throws {
        let fixture = try ReadinessFileFixture()
        defer { fixture.cleanup() }
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700])
        let sentinel = Data("owned sentinel\n".utf8)
        try sentinel.write(to: fixture.file)
        #expect(ReaderReadinessFileSink.make(arguments: fixture.arguments, cachesRoot: fixture.caches,
            debugBuild: true) == nil)
        #expect(try Data(contentsOf: fixture.file) == sentinel)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path) == [fixture.runID + ".jsonl"])
    }

    @Test func symlinkDirectoryBelowCacheRootIsRejected() throws {
        let fixture = try ReadinessFileFixture()
        defer { fixture.cleanup() }
        let outside = fixture.root.appendingPathComponent("owned-outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: fixture.directory, withDestinationURL: outside)
        #expect(ReaderReadinessFileSink.make(arguments: fixture.arguments, cachesRoot: fixture.caches,
            debugBuild: true) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: fixture.directory.path) == outside.path)
    }

    @Test func symlinkFinalDestinationIsRejectedWithoutFollowingIt() throws {
        let fixture = try ReadinessFileFixture()
        defer { fixture.cleanup() }
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: false)
        let outside = fixture.root.appendingPathComponent("owned-sentinel")
        let sentinel = Data("owned sentinel\n".utf8)
        try sentinel.write(to: outside)
        try FileManager.default.createSymbolicLink(at: fixture.file, withDestinationURL: outside)
        #expect(ReaderReadinessFileSink.make(arguments: fixture.arguments, cachesRoot: fixture.caches,
            debugBuild: true) == nil)
        #expect(try Data(contentsOf: outside) == sentinel)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: fixture.file.path) == outside.path)
    }

    #if DEBUG
    @Test func enabledCanonicalRunCreatesNewTraceFile() throws {
        let fixture = try ReadinessFileFixture()
        defer { fixture.cleanup() }
        let sink = try #require(ReaderReadinessFileSink.make(arguments: fixture.arguments,
            cachesRoot: fixture.caches, debugBuild: true), "Enabled canonical run must create a file sink")
        #expect(FileManager.default.fileExists(atPath: fixture.file.path))
        #expect(try Data(contentsOf: fixture.file).isEmpty)
        let line = try wire()
        #expect(sink.write(line))
        let bytes = try Data(contentsOf: fixture.file)
        #expect(bytes == Data(payload(line).utf8), "JSONL contains the validated payload plus exactly one LF")
        let event = try JSONDecoder().decode(ReaderReadinessEvent.self, from: bytes)
        #expect(event.schema == 1)
        #expect(event.navigation == 1)
        #expect(event.stage == .navigationStarted)
        #expect(try fixture.cacheEntries() == ["ToonEdgeReadinessDiagnostics"])
    }

    @Test func aSecondSinkCannotClaimTheSameRun() throws {
        let fixture = try ReadinessFileFixture()
        defer { fixture.cleanup() }
        let first = try #require(ReaderReadinessFileSink.make(arguments: fixture.arguments,
            cachesRoot: fixture.caches, debugBuild: true))
        #expect(first.write(try wire()))
        let before = try Data(contentsOf: fixture.file)
        #expect(ReaderReadinessFileSink.make(arguments: fixture.arguments, cachesRoot: fixture.caches,
            debugBuild: true) == nil)
        #expect(try Data(contentsOf: fixture.file) == before)
        #expect(first.write(try wire(.init(navigation: 1, elapsedMs: 1, stage: .navigationFinished))))
        let after = try Data(contentsOf: fixture.file)
        #expect(after.starts(with: before))
        #expect(after.split(separator: 10).count == 2)
    }

    @Test func canonicalizedStartingCacheRootIsAllowed() throws {
        let fixture = try ReadinessFileFixture()
        defer { fixture.cleanup() }
        let alias = fixture.root.appendingPathComponent("CachesAlias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: fixture.caches)
        let sink = try #require(ReaderReadinessFileSink.make(arguments: fixture.arguments,
            cachesRoot: alias, debugBuild: true))
        let line = try wire()
        #expect(sink.write(line))
        #expect(try Data(contentsOf: fixture.file) == Data(payload(line).utf8))
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: alias.path) == fixture.caches.path)
    }

    @Test func newDiagnosticsDirectoryAndTraceHavePrivatePermissions() throws {
        let fixture = try ReadinessFileFixture()
        defer { fixture.cleanup() }
        let sink = try #require(ReaderReadinessFileSink.make(arguments: fixture.arguments,
            cachesRoot: fixture.caches, debugBuild: true))
        #expect(sink.write(try wire()))
        let directoryAttributes = try FileManager.default.attributesOfItem(atPath: fixture.directory.path)
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fixture.file.path)
        let directoryMode = try #require(directoryAttributes[.posixPermissions] as? NSNumber).intValue
        let fileMode = try #require(fileAttributes[.posixPermissions] as? NSNumber).intValue
        #expect(directoryMode & 0o777 == 0o700)
        #expect(fileMode & 0o777 == 0o600)
        #expect(fileAttributes[.type] as? FileAttributeType == .typeRegular)
    }

    @Test func unsafeMalformedOrOutOfSchemaRecordsAreRejectedWithoutRetention() throws {
        let fixture = try ReadinessFileFixture()
        defer { fixture.cleanup() }
        let sink = try #require(ReaderReadinessFileSink.make(arguments: fixture.arguments,
            cachesRoot: fixture.caches, debugBuild: true))
        let valid = try wire()
        let object = try #require(JSONSerialization.jsonObject(with: Data(payload(valid).utf8)) as? [String: Any])
        var invalid = ["", "private arbitrary error\n", payload(valid), valid + valid,
            "TOONEDGE_READINESS_V2 " + payload(valid),
            ReaderReadinessDiagnostics.wirePrefix + "{\"source\":\"https://owned.invalid/?token=synthetic-secret\"}\n"]
        let mutations: [(String, Any)] = [
            ("sourceURL", "https://owned.invalid/?token=synthetic-secret"),
            ("cookie", "synthetic-secret"), ("body", "<html>synthetic-private-body</html>"),
            ("stage", "https://owned.invalid/synthetic-secret"), ("schema", 2),
            ("navigation", 0), ("navigation", 1_000_001), ("elapsedMs", -1), ("elapsedMs", 60_000),
            ("attempt", 7), ("attempt", 1), ("analysis", "recovery"),
            ("rawImages", -1), ("evidenceImages", 1_000_001), ("candidates", -1),
            ("score", 10_001), ("httpStatus", 99), ("httpStatus", 600),
            ("hardBlocks", ["synthetic-secret"]), ("transport", "synthetic-secret"),
            ("pixelWidth", "synthetic-secret"), ("preflight", "synthetic-secret")
        ]
        for (key, value) in mutations {
            var changed = object
            changed[key] = value
            invalid.append(try wireObject(changed))
        }
        var missing = object
        missing.removeValue(forKey: "schema")
        invalid.append(try wireObject(missing))
        for line in invalid { #expect(!sink.write(line), "Unsafe input must be rejected") }
        #expect(try Data(contentsOf: fixture.file).isEmpty)
        #expect(sink.write(valid), "Rejected records must leave the valid-record budget available")
        let bytes = try Data(contentsOf: fixture.file)
        #expect(bytes == Data(payload(valid).utf8))
        let exported = String(decoding: bytes, as: UTF8.self)
        for forbidden in ["https:", "synthetic-secret", "synthetic-private-body", "cookie", "sourceURL"] {
            #expect(!exported.contains(forbidden))
        }
        let exportedObject = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        #expect(Set(exportedObject.keys) == Set(object.keys))
    }

    @Test func oversizedInputIsRejectedBeforeAValidRecordCanBeAppended() throws {
        let fixture = try ReadinessFileFixture()
        defer { fixture.cleanup() }
        let sink = try #require(ReaderReadinessFileSink.make(arguments: fixture.arguments,
            cachesRoot: fixture.caches, debugBuild: true))
        let valid = try wire()
        let oversized = String(valid.dropLast()) + String(repeating: " ", count: 4_097) + "\n"
        #expect(oversized.utf8.count > 4_096)
        #expect(!sink.write(oversized))
        #expect(try Data(contentsOf: fixture.file).isEmpty)
        #expect(sink.write(valid))
        #expect(try Data(contentsOf: fixture.file) == Data(payload(valid).utf8))
    }

    @Test func acceptedRecordsRemainBoundedAcrossNavigationChanges() throws {
        let fixture = try ReadinessFileFixture()
        defer { fixture.cleanup() }
        let sink = try #require(ReaderReadinessFileSink.make(arguments: fixture.arguments,
            cachesRoot: fixture.caches, debugBuild: true))
        for index in 0..<129 {
            let event = ReaderReadinessEvent(navigation: index / 64 + 1, elapsedMs: index % 64,
                stage: .analysisStarted)
            #expect(sink.write(try wire(event)) == (index < 128))
        }
        let before = try Data(contentsOf: fixture.file)
        #expect(before.split(separator: 10).count == 128)
        #expect(before.count <= 512 * 1_024)
        #expect(before.last == 10)
        for record in before.split(separator: 10) {
            #expect(record.count + 1 <= 4_096)
            let event = try JSONDecoder().decode(ReaderReadinessEvent.self, from: Data(record))
            #expect((1...2).contains(event.navigation))
        }
        #expect(!sink.write(try wire(.init(navigation: 4, elapsedMs: 0, stage: .navigationStarted))))
        #expect(try Data(contentsOf: fixture.file) == before)
    }
    #endif
}
