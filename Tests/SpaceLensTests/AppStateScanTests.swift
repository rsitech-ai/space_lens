import Foundation
import XCTest
@testable import SpaceLens

final class AppStateScanTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceLensAppStateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
    }

    @MainActor
    func testStartScanPublishesStatisticsAndIntelligenceSummary() async throws {
        let buildFolder = temporaryRoot.appendingPathComponent(".build", isDirectory: true)
        try FileManager.default.createDirectory(at: buildFolder, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 256).write(to: buildFolder.appendingPathComponent("artifact.o"))

        let appState = AppState(
            smartCleanupScanner: SmartCleanupScanner(homeDirectory: temporaryRoot),
            requiresSecurityScopedAccess: false
        )
        appState.startScan(root: temporaryRoot)

        for _ in 0..<100 where appState.isScanning {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertFalse(appState.isScanning)
        XCTAssertNotNil(appState.rootNode)
        XCTAssertNotNil(appState.snapshot)
        XCTAssertNotNil(appState.scanStatistics)
        XCTAssertNotNil(appState.scanIntelligenceSummary)
        XCTAssertGreaterThan(appState.scanStatistics?.queueableCount ?? 0, 0)
        XCTAssertGreaterThan(appState.scanIntelligenceSummary?.recoverableBytes ?? 0, 0)
    }

    @MainActor
    func testRescanKeepsQueuedPathEvenWhenDisplayTreePrunesIt() async throws {
        let buildFolder = temporaryRoot.appendingPathComponent(".build", isDirectory: true)
        try FileManager.default.createDirectory(at: buildFolder, withIntermediateDirectories: true)
        try Data([1]).write(to: buildFolder.appendingPathComponent("artifact.o"))

        for index in 0..<300 {
            let file = temporaryRoot.appendingPathComponent("large-\(index).bin")
            FileManager.default.createFile(atPath: file.path, contents: nil)
            let handle = try FileHandle(forWritingTo: file)
            try handle.truncate(atOffset: 1_000_000)
            try handle.close()
        }

        let queuedNode = FileNode(
            url: buildFolder,
            isDirectory: true,
            logicalSize: 1,
            allocatedSize: 1
        )
        let appState = AppState(
            smartCleanupScanner: SmartCleanupScanner(homeDirectory: temporaryRoot),
            requiresSecurityScopedAccess: false
        )
        appState.cleanupQueue = [
            CleanupCandidate(
                fileNode: queuedNode,
                classification: appState.ruleEngine.classify(queuedNode),
                estimatedRecoverableBytes: queuedNode.effectiveSize,
                action: .queueForFutureTrash
            )
        ]

        appState.startScan(root: temporaryRoot)

        for _ in 0..<100 where appState.isScanning {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertFalse(appState.isScanning)
        XCTAssertEqual(appState.cleanupQueue.map { $0.fileNode.path }, [buildFolder.path])
    }

    @MainActor
    func testSmartScanPublishesVisibleCleanupCandidates() async throws {
        let buildFolder = temporaryRoot.appendingPathComponent("Project/.build", isDirectory: true)
        try FileManager.default.createDirectory(at: buildFolder, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 512).write(to: buildFolder.appendingPathComponent("artifact.o"))

        let appState = AppState(
            smartCleanupScanner: SmartCleanupScanner(homeDirectory: temporaryRoot),
            requiresSecurityScopedAccess: false
        )
        appState.startSmartScan(root: temporaryRoot)

        for _ in 0..<100 where appState.isScanning {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertFalse(appState.isScanning)
        XCTAssertEqual(appState.scanMode, .smart)
        XCTAssertEqual(appState.visibleNodes.map(\.node.displayName), ["Build Artifacts (.build)"])
        XCTAssertGreaterThan(appState.visibleCleanupReadyCount, 0)
    }

    @MainActor
    func testFreshAppDoesNotAssumeHomeDirectoryIsAuthorizedForSmartScan() {
        let appState = AppState(
            smartCleanupScanner: SmartCleanupScanner(homeDirectory: temporaryRoot)
        )

        XCTAssertNil(appState.authorizedSmartScanRoot)
    }
}
