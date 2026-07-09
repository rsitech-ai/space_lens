import Foundation
import XCTest
@testable import SpaceLens

final class AppSessionStoreTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceLensSessionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
    }

    @MainActor
    func testSessionStorePersistsRootAndCleanupPaths() throws {
        let sessionURL = temporaryRoot.appendingPathComponent("session.json")
        let store = AppSessionStore(fileURL: sessionURL)
        let cacheURL = temporaryRoot.appendingPathComponent(".build", isDirectory: true)
        let cacheNode = FileNode(url: cacheURL, isDirectory: true, logicalSize: 100, allocatedSize: 120)
        let candidate = CleanupCandidate(
            fileNode: cacheNode,
            classification: SafetyClassification(
                level: .rebuildableCache,
                confidence: 0.9,
                category: "Rebuildable cache",
                summary: "Safe to queue",
                evidence: [],
                recommendedAction: "Safe to queue"
            ),
            estimatedRecoverableBytes: 120,
            action: .queueForFutureTrash
        )

        try store.save(rootURL: temporaryRoot, cleanupQueue: [candidate])

        let restoredSession = try XCTUnwrap(store.load())
        XCTAssertEqual(restoredSession.rootPath, temporaryRoot.standardizedFileURL.path)
        XCTAssertEqual(restoredSession.cleanupPaths, [cacheURL.path])
        XCTAssertNotNil(store.resolveRootURL(from: restoredSession))
    }

    @MainActor
    func testSessionStoreQuarantinesCorruptState() throws {
        let sessionURL = temporaryRoot.appendingPathComponent("session.json")
        let store = AppSessionStore(fileURL: sessionURL)
        try Data("not json".utf8).write(to: sessionURL)

        XCTAssertNil(store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: sessionURL.path))

        let quarantinedFiles = try FileManager.default.contentsOfDirectory(
            at: temporaryRoot,
            includingPropertiesForKeys: nil
        )
        XCTAssertTrue(quarantinedFiles.contains { $0.lastPathComponent.hasPrefix("session.corrupt-") })
    }

    @MainActor
    func testAppStateRestoresCleanupQueueAfterRelaunch() async throws {
        let sessionURL = temporaryRoot.appendingPathComponent("session.json")
        let store = AppSessionStore(fileURL: sessionURL)
        let cacheFolder = temporaryRoot
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent("package-cache", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 512).write(to: cacheFolder.appendingPathComponent("artifact.o"))

        let firstLaunch = AppState(sessionStore: store)
        firstLaunch.startScan(root: temporaryRoot)
        try await waitForScanToFinish(firstLaunch)

        let cacheNode = try XCTUnwrap(firstLaunch.visibleNodes.first { $0.node.displayName == "package-cache" }?.node)
        let cacheFolderPath = cacheNode.path
        firstLaunch.addToCleanupQueue(node: cacheNode)
        XCTAssertEqual(firstLaunch.cleanupQueue.map(\.fileNode.path), [cacheFolderPath])

        let restoredLaunch = AppState(
            sessionStore: store,
            restoreOnLaunch: true,
            smartCleanupScanner: SmartCleanupScanner(homeDirectory: temporaryRoot)
        )
        XCTAssertFalse(restoredLaunch.isScanning)
        XCTAssertNil(restoredLaunch.rootNode)

        restoredLaunch.smartScan()
        try await waitForScanToFinish(restoredLaunch)

        XCTAssertEqual(
            restoredLaunch.cleanupQueue.first.map { URL(fileURLWithPath: $0.fileNode.path).resolvingSymlinksInPath().path },
            URL(fileURLWithPath: cacheFolderPath).resolvingSymlinksInPath().path
        )
        XCTAssertEqual(restoredLaunch.cleanupStatusMessage, "Restored 1 cleanup queued items")
    }

    @MainActor
    func testAppStateRestoresCleanupQueueFromCanonicalPathVariant() async throws {
        let sessionURL = temporaryRoot.appendingPathComponent("session.json")
        let store = AppSessionStore(fileURL: sessionURL)
        let cacheFolder = temporaryRoot
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent("package-cache", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 512).write(to: cacheFolder.appendingPathComponent("artifact.o"))

        let variantCleanupPath = cacheFolder.path.hasPrefix("/var/")
            ? "/private" + cacheFolder.path
            : cacheFolder.path
        try store.save(
            PersistedAppSession(
                rootPath: temporaryRoot.path,
                rootBookmarkData: nil,
                cleanupPaths: [variantCleanupPath]
            )
        )

        let restoredLaunch = AppState(
            sessionStore: store,
            restoreOnLaunch: true,
            smartCleanupScanner: SmartCleanupScanner(homeDirectory: temporaryRoot)
        )
        XCTAssertFalse(restoredLaunch.isScanning)
        XCTAssertNil(restoredLaunch.rootNode)

        restoredLaunch.smartScan()
        try await waitForScanToFinish(restoredLaunch)

        XCTAssertEqual(restoredLaunch.cleanupQueue.count, 1)
        XCTAssertEqual(restoredLaunch.cleanupQueue.first?.fileNode.displayName, "package-cache")
        XCTAssertEqual(
            restoredLaunch.cleanupQueue.first.map { URL(fileURLWithPath: $0.fileNode.path).resolvingSymlinksInPath().path },
            URL(fileURLWithPath: cacheFolder.path).resolvingSymlinksInPath().path
        )
        XCTAssertEqual(restoredLaunch.cleanupStatusMessage, "Restored 1 cleanup queued items")
    }

    @MainActor
    private func waitForScanToFinish(_ appState: AppState) async throws {
        for _ in 0..<120 {
            if !appState.isScanning, appState.rootNode != nil {
                return
            }
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTFail("Timed out waiting for scan")
    }
}
