import Foundation
import XCTest
@testable import SpaceLens

final class DiskScannerTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceLensTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
    }

    func testScannerCalculatesFolderSizesAndSortsChildren() async throws {
        let small = temporaryRoot.appendingPathComponent("small.txt")
        let large = temporaryRoot.appendingPathComponent("large.txt")

        try Data(repeating: 1, count: 32).write(to: small)
        try Data(repeating: 1, count: 128).write(to: large)

        let result = await DiskScanner().scan(root: temporaryRoot)

        XCTAssertEqual(result.snapshot.nodeCount, 3)
        XCTAssertEqual(result.root.children.first?.name, "large.txt")
        XCTAssertGreaterThanOrEqual(result.root.logicalSize, 160)
    }

    func testScannerRecordsMissingRootAsError() async throws {
        let missing = temporaryRoot.appendingPathComponent("missing")
        let result = await DiskScanner().scan(root: missing)

        XCTAssertNotNil(result.root.scanError)
        XCTAssertEqual(result.snapshot.errorCount, 1)
    }

    func testScannerDoesNotFollowSymlinkAsDirectoryTree() async throws {
        let realDirectory = temporaryRoot.appendingPathComponent("real", isDirectory: true)
        let linkedDirectory = temporaryRoot.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createDirectory(at: realDirectory, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 64).write(to: realDirectory.appendingPathComponent("inside.txt"))
        try FileManager.default.createSymbolicLink(at: linkedDirectory, withDestinationURL: realDirectory)

        let result = await DiskScanner().scan(root: temporaryRoot)
        let symlink = result.root.children.first { $0.name == "linked" }

        XCTAssertEqual(symlink?.isSymlink, true)
        XCTAssertEqual(symlink?.children.count, 0)
    }

    func testScannerPublishesRealProgressCounts() async throws {
        let recorder = ProgressRecorder()
        let nested = temporaryRoot.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 64).write(to: temporaryRoot.appendingPathComponent("top.txt"))
        try Data(repeating: 1, count: 96).write(to: nested.appendingPathComponent("child.txt"))

        let result = await DiskScanner().scan(root: temporaryRoot) { progress in
            recorder.record(progress)
        }

        let updates = recorder.updates
        let finalProgress = try XCTUnwrap(updates.last)
        XCTAssertFalse(updates.isEmpty)
        XCTAssertEqual(finalProgress.scannedCount, result.snapshot.nodeCount)
        XCTAssertEqual(finalProgress.fileCount, 2)
        XCTAssertEqual(finalProgress.directoryCount, 2)
        XCTAssertEqual(finalProgress.errorCount, result.snapshot.errorCount)
        XCTAssertGreaterThan(finalProgress.discoveredBytes, 0)
    }

    func testScannerThrottlesProgressForLargeTrees() async throws {
        let recorder = ProgressRecorder()

        for index in 0..<1_100 {
            let file = temporaryRoot.appendingPathComponent("file-\(index).txt")
            try Data([1]).write(to: file)
        }

        let result = await DiskScanner().scan(root: temporaryRoot) { progress in
            recorder.record(progress)
        }

        let updates = recorder.updates
        XCTAssertEqual(updates.last?.scannedCount, result.snapshot.nodeCount)
        XCTAssertLessThan(updates.count, result.snapshot.nodeCount / 10)
    }
}

private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ScanProgress] = []

    var updates: [ScanProgress] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ progress: ScanProgress) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(progress)
    }
}
