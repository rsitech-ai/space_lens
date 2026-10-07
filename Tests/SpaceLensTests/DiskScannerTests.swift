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

    func testScannerBoundsRetainedChildrenWithoutStoppingFullTraversal() async throws {
        var expectedLogicalSize: Int64 = 0
        for index in 1...12 {
            let size = Int64(index * 1_000_000)
            let file = temporaryRoot.appendingPathComponent(String(format: "file-%02d.bin", index))
            FileManager.default.createFile(atPath: file.path, contents: nil)
            let handle = try FileHandle(forWritingTo: file)
            try handle.truncate(atOffset: UInt64(size))
            try handle.close()
            expectedLogicalSize += size
        }

        let result = await DiskScanner().scan(
            root: temporaryRoot,
            options: ScanOptions(maxRetainedChildrenPerDirectory: 3)
        )

        XCTAssertEqual(result.snapshot.nodeCount, 13)
        XCTAssertEqual(result.snapshot.fileCount, 12)
        XCTAssertEqual(result.snapshot.directoryCount, 1)
        XCTAssertEqual(result.root.children.map(\.name), ["file-12.bin", "file-11.bin", "file-10.bin"])
        XCTAssertEqual(result.root.children.count, 3)
        XCTAssertGreaterThanOrEqual(result.root.logicalSize, expectedLogicalSize)
    }

    func testWholeScanBoundsNodesAcrossManySmallDirectories() async throws {
        for directoryIndex in 0..<128 {
            let directory = temporaryRoot.appendingPathComponent("d\(directoryIndex)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for fileIndex in 0..<80 {
                try Data([1]).write(to: directory.appendingPathComponent("f\(fileIndex)"))
            }
        }

        let result = await DiskScanner().scan(root: temporaryRoot)

        XCTAssertEqual(result.snapshot.nodeCount, 10_369)
        XCTAssertEqual(result.snapshot.fileCount, 10_240)
        XCTAssertEqual(result.root.logicalSize, 10_240)
        XCTAssertLessThanOrEqual(result.root.flattened().count, 10_000)
    }

    func testBudgetOneStillMeasuresDescendantsAndDoesNotFollowLinks() async throws {
        let folder = temporaryRoot.appendingPathComponent("folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: folder.appendingPathComponent("data"))
        try FileManager.default.createSymbolicLink(
            at: temporaryRoot.appendingPathComponent("linked"), withDestinationURL: folder
        )
        let options = ScanOptions(maxRetainedChildrenPerDirectory: 256, maxRetainedNodes: 1)
        let result = await DiskScanner().scan(root: temporaryRoot, options: options)
        let reference = await DiskScanner().scan(root: temporaryRoot, options: .fullRetention)

        XCTAssertEqual(result.root.flattened().count, 1)
        XCTAssertEqual(result.createdNodeCount, 1)
        XCTAssertEqual(result.snapshot.nodeCount, reference.snapshot.nodeCount)
        XCTAssertEqual(result.snapshot.symlinkCount, 1)
        XCTAssertEqual(result.root.logicalSize, reference.root.logicalSize)
        XCTAssertEqual(result.root.allocatedSize, reference.root.allocatedSize)
        XCTAssertTrue(result.snapshot.hasLimitedDetails)
    }

    func testSmallBudgetPreservesSiblingOverviewAndCompleteTotals() async throws {
        for index in 0..<3 {
            let folder = temporaryRoot.appendingPathComponent("d\(index)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for child in 0..<10 {
                try Data([1, 2]).write(to: folder.appendingPathComponent("f\(child)"))
            }
        }
        for budget in [2, 4, 7, 16] {
            let result = await DiskScanner().scan(
                root: temporaryRoot,
                options: ScanOptions(maxRetainedChildrenPerDirectory: 256, maxRetainedNodes: budget)
            )
            XCTAssertLessThanOrEqual(result.root.flattened().count, budget)
            XCTAssertEqual(result.snapshot.nodeCount, 34)
            XCTAssertEqual(result.root.logicalSize, 60)
            if budget >= 4 { XCTAssertEqual(result.root.children.count, 3) }
        }
    }

    func testCollapsedReadErrorPropagatesThroughBoundedParents() async throws {
        let blocked = temporaryRoot.appendingPathComponent("branch/blocked")
        try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: true)
        try Data([1]).write(to: blocked.appendingPathComponent("data"))
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: blocked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: blocked.path) }
        let result = await DiskScanner().scan(
            root: temporaryRoot,
            options: ScanOptions(maxRetainedChildrenPerDirectory: 256, maxRetainedNodes: 2)
        )
        XCTAssertGreaterThan(result.snapshot.errorCount, 0)
        XCTAssertNotNil(result.root.scanError)
        XCTAssertNotNil(result.root.children.first?.scanError)
    }

    func testResolvedScopeRejectsAPFSDataVolumeFirmlink() throws {
        let data = URL(fileURLWithPath: "/System/Volumes/Data")
        let users = data.appendingPathComponent("Users")
        guard FileManager.default.fileExists(atPath: users.path), users.resolvingSymlinksInPath().path == "/Users" else {
            throw XCTSkip("Host does not expose the macOS Data-volume Users firmlink")
        }
        XCTAssertNotNil(DiskScanner.traversalIssue(users, resolvedRootPath: data.resolvingSymlinksInPath().path))
        XCTAssertNotNil(DiskScanner.traversalIssue(users, resolvedRootPath: "/"))
        XCTAssertNil(DiskScanner.traversalIssue(URL(fileURLWithPath: "/Users"), resolvedRootPath: "/"))
        XCTAssertNotNil(DiskScanner.traversalIssue(URL(fileURLWithPath: "/Users/s1kor-other"), resolvedRootPath: "/Users/s1kor"))
    }

    func testVirtualDeviceNamespaceIsSkippedInBothRetentionModes() async throws {
        for options in [ScanOptions.appDefault, .collapsed] {
            let result = await DiskScanner().scan(root: URL(fileURLWithPath: "/dev"), options: options)
            XCTAssertEqual(result.snapshot.nodeCount, 1)
            XCTAssertEqual(result.snapshot.errorCount, 1)
            XCTAssertEqual(result.root.logicalSize, 0)
            XCTAssertTrue(result.root.children.isEmpty)
            XCTAssertNotNil(result.root.scanError)
            XCTAssertFalse(RuleEngine().classify(result.root).level.isQueueable)
        }
    }

    func testWholeDriveTraversalRejectsKernelRootAliases() {
        for path in ["/.nofollow", "/.nofollow/Users", "/.resolve", "/.resolve/Users"] {
            XCTAssertNotNil(DiskScanner.traversalIssue(URL(fileURLWithPath: path), resolvedRootPath: "/"))
        }
        XCTAssertNil(DiskScanner.traversalIssue(URL(fileURLWithPath: "/Users/.nofollow"), resolvedRootPath: "/"))
        XCTAssertNil(DiskScanner.traversalIssue(URL(fileURLWithPath: "/.nofollow-other"), resolvedRootPath: "/"))
    }

    func testKernelPathNamespacesAreSkippedInBothRetentionModes() async {
        for path in ["/.nofollow", "/.nofollow/Users", "/.resolve"] {
            for options in [ScanOptions.appDefault, .collapsed] {
                let result = await DiskScanner().scan(root: URL(fileURLWithPath: path), options: options)
                XCTAssertEqual(result.snapshot.nodeCount, 1)
                XCTAssertEqual(result.snapshot.errorCount, 1)
                XCTAssertEqual(result.root.logicalSize, 0)
                XCTAssertTrue(result.root.children.isEmpty)
                XCTAssertFalse(RuleEngine().classify(result.root).level.isQueueable)
            }
        }
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

    func testCollapsedScanSizesThousandsOfFilesWithoutMaterializingNodes() async throws {
        let derivedData = temporaryRoot.appendingPathComponent("DerivedData", isDirectory: true)
        try FileManager.default.createDirectory(at: derivedData, withIntermediateDirectories: true)
        let fileCount = 3_000
        for index in 0..<fileCount {
            FileManager.default.createFile(
                atPath: derivedData.appendingPathComponent("f\(index).o").path,
                contents: Data()
            )
        }

        let started = Date()
        let result = await DiskScanner().scan(root: derivedData, options: .collapsed)
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertEqual(result.root.children.count, 0)
        XCTAssertEqual(result.createdNodeCount, 1)
        XCTAssertEqual(result.snapshot.fileCount, fileCount)
        XCTAssertEqual(result.snapshot.directoryCount, 1)
        XCTAssertLessThan(elapsed, 30)
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

    func testCollapsedScanStopsWhenCancelled() async throws {
        let derivedData = temporaryRoot.appendingPathComponent("DerivedData", isDirectory: true)
        try FileManager.default.createDirectory(at: derivedData, withIntermediateDirectories: true)
        let fileCount = 6_000
        for index in 0..<fileCount {
            FileManager.default.createFile(
                atPath: derivedData.appendingPathComponent("f\(index).o").path,
                contents: Data()
            )
        }

        let started = Date()
        let task = Task {
            await DiskScanner().scan(root: derivedData, options: .collapsed)
        }
        try await Task.sleep(nanoseconds: 15_000_000)
        task.cancel()
        let result = await task.value

        XCTAssertEqual(result.createdNodeCount, 1)
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
        XCTAssertLessThanOrEqual(result.snapshot.fileCount, fileCount)
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
