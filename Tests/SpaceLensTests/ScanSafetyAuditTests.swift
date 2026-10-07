import Foundation
import XCTest
@testable import SpaceLens

final class ScanSafetyAuditTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("SpaceLensAudit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testIncompleteBuildCannotBeQueueableInEitherScanMode() async throws {
        let build = root.appendingPathComponent("Project/.build")
        let blocked = build.appendingPathComponent("blocked")
        try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: true)
        try Data([1]).write(to: build.appendingPathComponent("object.o"))
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: blocked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: blocked.path) }
        for options in [ScanOptions.collapsed, .appDefault] {
            let result = await DiskScanner().scan(root: build, options: options)
            XCTAssertGreaterThan(result.snapshot.errorCount, 0)
            XCTAssertNotNil(result.root.scanError)
            XCTAssertFalse(RuleEngine().classify(result.root).level.isQueueable)
        }
        let smart = await SmartCleanupScanner(homeDirectory: root).scan(root: root)
        XCTAssertFalse(try XCTUnwrap(smart.root.children.first).scanError == nil)
    }

    func testRebuildEvidenceSurvivesSmartDisplayNamesAndIsRechecked() async throws {
        let target = root.appendingPathComponent("Documents/rust/target")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let manifest = target.deletingLastPathComponent().appendingPathComponent("Cargo.toml")
        try Data("[package]".utf8).write(to: manifest)
        try Data([1]).write(to: target.appendingPathComponent("artifact"))
        let result = await SmartCleanupScanner(homeDirectory: root).scan(root: root)
        let node = try XCTUnwrap(result.root.children.first { $0.path == target.path })
        XCTAssertTrue(RuleEngine().classify(node).level.isQueueable)
        try FileManager.default.removeItem(at: manifest)
        XCTAssertThrowsError(try FileCleanupService.validatedCleanupURL(for: node, authorizedRoot: root))
    }

    func testMissingLockfileAndArbitraryTargetRequireReview() throws {
        for name in ["node_modules", "target"] {
            let url = root.appendingPathComponent("dev/app/\(name)")
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            let node = FileNode(url: url, isDirectory: true, logicalSize: 100, allocatedSize: 100)
            XCTAssertFalse(RuleEngine().classify(node).level.isQueueable)
            XCTAssertThrowsError(try FileCleanupService.validatedCleanupURL(for: node, authorizedRoot: root))
        }
    }

    func testSharedTmpAndCursorPersistentStateNeverQueue() {
        for path in ["/private/tmp", "/tmp", "/Users/example/Library/Application Support/Cursor/Partitions", "/Users/example/Library/Application Support/Cursor/WebStorage", "/Users/example/Library/pnpm"] {
            let node = FileNode(url: URL(fileURLWithPath: path), isDirectory: true, logicalSize: 100, allocatedSize: 100)
            XCTAssertFalse(RuleEngine().classify(node).level.isQueueable, path)
        }
    }

    func testFailedActivityInspectionCannotBecomeIdle() {
        let node = FileNode(url: root.appendingPathComponent(".build"), isDirectory: true, logicalSize: 100, allocatedSize: 100)
        let unavailable = PathUseSnapshot(runningToolLabels: [], xcodeFamilyActive: false, dockerActive: false, cursorActive: false, cargoActive: false, activityCheckError: "lsof timed out")
        XCTAssertFalse(RuleEngine().classify(node, pathUse: unavailable).level.isQueueable)
        XCTAssertEqual(unavailable.withOpenPaths([]).activityCheckError, "lsof timed out")
    }

    func testActivityMatchingHandlesAPFSAliasesAndCaseSensitiveVolumes() {
        XCTAssertTrue(PathUseDetector.pathIsOpen("/Users/example/dev/app/.build", openPaths: ["/System/Volumes/Data/Users/example/dev/app/.build/artifact.o"]))
        XCTAssertTrue(PathUseDetector.pathIsOpen("/private/tmp/cache", openPaths: ["/tmp/cache/object"]))
        XCTAssertFalse(PathUseDetector.pathIsOpen("/Volumes/CaseSensitive/cache", openPaths: ["/Volumes/CaseSensitive/Cache/object"]))
    }

    func testActivityIndexDoesNotRescanEveryOpenFileForEveryCandidate() {
        let opens = (0..<5000).map { "/Users/example/dev/unrelated/cache/file-\($0)" }
        let snapshot = PathUseDetector.snapshot(runningProcessNames: [], openPaths: opens)
        let start = Date()
        for index in 0..<1000 { XCTAssertFalse(snapshot.isPathOpen("/Users/example/dev/app-\(index)/.build")) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testDiscoveryBudgetReportsIncompleteRoots() async throws {
        let dev = root.appendingPathComponent("dev/app/.build")
        try FileManager.default.createDirectory(at: dev, withIntermediateDirectories: true)
        try Data([1]).write(to: dev.appendingPathComponent("artifact"))
        let result = await SmartCleanupScanner(homeDirectory: root, discoveryBudget: 0).scan(root: root)
        XCTAssertFalse(result.pendingDiscoveryPaths.isEmpty)
    }

    func testCatalogAndDiscoveryDoNotDoubleCountNestedCaches() async throws {
        let cache = root.appendingPathComponent("Library/Caches/Yarn/cache")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data([1]).write(to: cache.appendingPathComponent("dependency"))
        let result = await SmartCleanupScanner(homeDirectory: root).scan(root: root)
        XCTAssertEqual(result.root.children.count, 1)
        XCTAssertEqual(result.snapshot.fileCount, 1)
    }

    func testSimulatorInventoryCannotEscapeSelectedRoot() async throws {
        let outside = root.appendingPathComponent("outside/device/data")
        let selected = root.appendingPathComponent("selected")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: selected, withIntermediateDirectories: true)
        try Data([1]).write(to: outside.appendingPathComponent("state"))
        let inventory = SimulatorInventory(devices: [SimulatorDevice(udid: "A", name: "Fixture", runtime: "iOS", state: "Shutdown", isAvailable: true, dataPath: outside.path)])
        let result = await SmartCleanupScanner(homeDirectory: selected, simulatorInventory: inventory).scan(root: selected)
        XCTAssertTrue(result.root.children.isEmpty)
    }

    func testSmartScanFindsLockedWebBuildAndStaleDiagnostics() async throws {
        let web = root.appendingPathComponent("dev/web/.next")
        let logs = root.appendingPathComponent("Library/Logs")
        try FileManager.default.createDirectory(at: web, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        try Data([1]).write(to: web.appendingPathComponent("bundle"))
        try Data("{}".utf8).write(to: web.deletingLastPathComponent().appendingPathComponent("package.json"))
        try Data("{}".utf8).write(to: web.deletingLastPathComponent().appendingPathComponent("package-lock.json"))
        let stale = logs.appendingPathComponent("old.log")
        try Data([1]).write(to: stale)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -30 * 86400)], ofItemAtPath: stale.path)
        try Data([1]).write(to: logs.appendingPathComponent("recent.log"))
        let result = await SmartCleanupScanner(homeDirectory: root).scan(root: root)
        XCTAssertTrue(result.root.children.contains { $0.path == web.path && RuleEngine(homeDirectory: root).classify($0).level.isQueueable })
        XCTAssertTrue(result.root.children.contains { $0.path == stale.path })
        XCTAssertFalse(result.root.children.contains { $0.path.hasSuffix("recent.log") })
    }

    func testCancelledProcessStartupIsSafeAndNonzeroExitFails() async {
        for _ in 0..<30 {
            let task = Task { await BoundedProcess.run(executable: "/bin/sleep", arguments: ["0.02"], timeout: 1) }
            task.cancel()
            let output = await task.value
            XCTAssertNil(output)
        }
        let failed = await BoundedProcess.run(executable: "/usr/bin/false", arguments: [], timeout: 1)
        XCTAssertNil(failed)
        let started = Date()
        let timedOut = await BoundedProcess.run(executable: "/bin/sleep", arguments: ["4"], timeout: 0.05)
        XCTAssertNil(timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    }

    @MainActor
    func testCleanupRefreshesActivityAndRejectsNewlyActiveBuild() async throws {
        let build = root.appendingPathComponent(".build")
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        try Data([1]).write(to: build.appendingPathComponent("object.o"))
        let state = AppState(activitySnapshot: { PathUseDetector.snapshot(runningProcessNames: ["xcodebuild"], openPaths: []) }, requiresSecurityScopedAccess: false)
        state.startScan(root: root)
        for _ in 0..<200 where state.isScanning { try await Task.sleep(for: .milliseconds(20)) }
        let node = try XCTUnwrap(state.rootNode?.children.first)
        XCTAssertTrue(state.classification(for: node).level.isQueueable)
        state.addToCleanupQueue(node: node)
        XCTAssertFalse(state.cleanupQueue.isEmpty)
        await state.moveToBin(node: node)
        XCTAssertTrue(state.cleanupQueue.isEmpty)
        XCTAssertEqual(state.scanStatistics?.queueableCount, 0)
        XCTAssertEqual(state.scanStatistics?.queueableBytes, 0)
        XCTAssertNotNil(state.latestError)
        XCTAssertTrue(FileManager.default.fileExists(atPath: build.path))
    }

    func testRemovingRetainedChildPreservesUnretainedSize() throws {
        let url = root.appendingPathComponent(".build")
        let child = FileNode(url: url.appendingPathComponent("object"), isDirectory: false, logicalSize: 10, allocatedSize: 10)
        let parent = FileNode(url: url, isDirectory: true, logicalSize: 100, allocatedSize: 100, children: [child])
        let remaining = try XCTUnwrap(parent.removing(id: child.id))
        XCTAssertEqual(remaining.logicalSize, 90)
        XCTAssertEqual(remaining.allocatedSize, 90)
    }

    @MainActor
    func testRescanRebindsQueueToNewVisibleNodes() async throws {
        let build = root.appendingPathComponent(".build")
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        try Data([1]).write(to: build.appendingPathComponent("object"))
        let state = AppState(smartCleanupScanner: SmartCleanupScanner(homeDirectory: root), requiresSecurityScopedAccess: false)
        state.startSmartScan(root: root)
        for _ in 0..<200 where state.isScanning { try await Task.sleep(for: .milliseconds(20)) }
        let previous = try XCTUnwrap(state.cleanupQueue.first?.fileNode.id)
        state.startSmartScan(root: root)
        for _ in 0..<200 where state.isScanning { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(state.cleanupQueue.count, 1)
        XCTAssertNotEqual(state.cleanupQueue.first?.fileNode.id, previous)
        XCTAssertEqual(state.visibleNodes.first?.node.id, state.cleanupQueue.first?.fileNode.id)
        XCTAssertNotNil(state.selectedNode)
    }

    @MainActor
    func testCancelledLiveScanRequiresRescanBeforeCleanup() async throws {
        let state = AppState(smartCleanupScanner: SmartCleanupScanner(homeDirectory: root), requiresSecurityScopedAccess: false)
        state.startSmartScan(root: root)
        XCTAssertFalse(state.canCleanUp)
        state.cancelScan()
        XCTAssertFalse(state.canCleanUp)
        XCTAssertNil(state.rootNode)
        XCTAssertNil(state.snapshot)
    }
    func testDataVolumeRootDoesNotScheduleOutsideHomeAliases() {
        let dataRoot = URL(fileURLWithPath: "/System/Volumes/Data")
        let scanner = SmartCleanupScanner()
        XCTAssertEqual(scanner.scheduledDiscoveryRoots(containedIn: dataRoot).map(\.path), [dataRoot.path])
        XCTAssertTrue(SmartScanCatalog.extraSystemRoots(scanRoot: dataRoot, homeDirectory: FileManager.default.homeDirectoryForCurrentUser).isEmpty)
    }

    func testSimulatorInspectionRunsOnlyForAnIntersectingScope() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let scanner = SmartCleanupScanner(homeDirectory: home)
        XCTAssertFalse(scanner.shouldLoadSimulatorInventory(for: home.appendingPathComponent("dev/app")))
        XCTAssertTrue(scanner.shouldLoadSimulatorInventory(for: home))
        XCTAssertTrue(scanner.shouldLoadSimulatorInventory(for: home.appendingPathComponent("Library/Developer/CoreSimulator/Devices")))
        XCTAssertTrue(scanner.shouldLoadSimulatorInventory(for: home.appendingPathComponent("Library/Developer")))
        XCTAssertTrue(scanner.shouldLoadSimulatorInventory(for: URL(fileURLWithPath: "/Library/Developer/CoreSimulator/Devices")))
        XCTAssertTrue(scanner.shouldLoadSimulatorInventory(for: URL(fileURLWithPath: "/Library/Developer/CoreSimulator/Devices/booted-device")))
        XCTAssertFalse(scanner.shouldLoadSimulatorInventory(for: URL(fileURLWithPath: "/System/Volumes/Data")))
    }

}
