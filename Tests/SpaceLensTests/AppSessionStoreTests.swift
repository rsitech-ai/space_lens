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
    func testClearRemovesActiveAndQuarantinedSessionFiles() throws {
        let sessionURL = temporaryRoot.appendingPathComponent("session.json")
        let store = AppSessionStore(fileURL: sessionURL)
        try store.save(
            PersistedAppSession(
                rootPath: "/private/example",
                rootBookmarkData: Data([1, 2, 3]),
                cleanupPaths: ["/private/example/.build"]
            )
        )
        try Data("old corrupt session".utf8).write(
            to: temporaryRoot.appendingPathComponent("session.corrupt-1.json")
        )
        try Data("new corrupt session".utf8).write(
            to: temporaryRoot.appendingPathComponent("session.corrupt-2.json")
        )

        try store.clear()

        let remainingSessionFiles = try FileManager.default.contentsOfDirectory(
            at: temporaryRoot,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent == "session.json" || $0.lastPathComponent.hasPrefix("session.corrupt-") }
        XCTAssertTrue(remainingSessionFiles.isEmpty)
    }

    @MainActor
    func testCorruptSessionQuarantineKeepsOnlyThreeNewestCopies() throws {
        let sessionURL = temporaryRoot.appendingPathComponent("session.json")
        let store = AppSessionStore(fileURL: sessionURL)

        for index in 0..<5 {
            try Data("not json \(index)".utf8).write(to: sessionURL, options: .atomic)
            XCTAssertNil(store.load())
        }

        let quarantinedFiles = try FileManager.default.contentsOfDirectory(
            at: temporaryRoot,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("session.corrupt-") && $0.pathExtension == "json" }
        XCTAssertEqual(quarantinedFiles.count, 3)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sessionURL.path))
    }

    @MainActor
    func testSessionStoreDoesNotTreatRawPathAsRestoredAuthorization() throws {
        let sessionURL = temporaryRoot.appendingPathComponent("session.json")
        let store = AppSessionStore(fileURL: sessionURL)
        let session = PersistedAppSession(
            rootPath: temporaryRoot.path,
            rootBookmarkData: nil,
            cleanupPaths: []
        )

        XCTAssertNil(store.resolveRootURL(from: session))
    }

    @MainActor
    func testSandboxedScanStopsWhenSecurityScopeCannotBeAcquired() {
        let appState = AppState(
            requiresSecurityScopedAccess: true,
            startSecurityScopedAccess: { _ in false }
        )

        appState.startScan(root: temporaryRoot)

        XCTAssertFalse(appState.isScanning)
        XCTAssertNil(appState.currentAuthorizedScanRoot)
        XCTAssertEqual(
            appState.latestError,
            "SpaceLens could not access that folder. Select it again to refresh permission."
        )
    }

    @MainActor
    func testAppStateRestoresCleanupQueueAfterRelaunch() async throws {
        let sessionURL = temporaryRoot.appendingPathComponent("session.json")
        let store = AppSessionStore(fileURL: sessionURL)
        let cacheFolder = temporaryRoot
            .appendingPathComponent(".build", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 512).write(to: cacheFolder.appendingPathComponent("artifact.o"))

        let firstLaunch = AppState(
            sessionStore: store,
            smartCleanupScanner: SmartCleanupScanner(homeDirectory: temporaryRoot),
            requiresSecurityScopedAccess: false
        )
        firstLaunch.startSmartScan(root: temporaryRoot)
        try await waitForScanToFinish(firstLaunch)

        let cacheNode = try XCTUnwrap(
            firstLaunch.rootNode?.flattened().first { $0.node.path == cacheFolder.path }?.node
        )
        let cacheFolderPath = cacheNode.path
        firstLaunch.addToCleanupQueue(node: cacheNode)
        XCTAssertEqual(firstLaunch.cleanupQueue.map(\.fileNode.path), [cacheFolderPath])

        let restoredLaunch = AppState(
            sessionStore: store,
            restoreOnLaunch: true,
            smartCleanupScanner: SmartCleanupScanner(homeDirectory: temporaryRoot),
            requiresSecurityScopedAccess: false
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
    func testAppStateRequiresReselectionWhenSavedSessionHasNoBookmark() throws {
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

        let restoredLaunch = AppState(sessionStore: store, restoreOnLaunch: true)
        XCTAssertFalse(restoredLaunch.isScanning)
        XCTAssertNil(restoredLaunch.rootNode)
        XCTAssertNil(restoredLaunch.authorizedSmartScanRoot)
        XCTAssertTrue(restoredLaunch.cleanupQueue.isEmpty)
        XCTAssertEqual(
            restoredLaunch.latestError,
            "SpaceLens could not restore the last folder. Select it again to refresh saved access."
        )
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

    @MainActor
    func testForgetSavedSessionClearsPersistedFolderAndCleanupQueue() throws {
        let sessionURL = temporaryRoot.appendingPathComponent("session.json")
        let store = AppSessionStore(fileURL: sessionURL)
        let selectedRoot = temporaryRoot.appendingPathComponent("Selected", isDirectory: true)
        let buildFolder = selectedRoot.appendingPathComponent(".build", isDirectory: true)
        try FileManager.default.createDirectory(at: buildFolder, withIntermediateDirectories: true)
        let node = FileNode(url: buildFolder, isDirectory: true, logicalSize: 1, allocatedSize: 1)
        try store.save(rootURL: selectedRoot, cleanupQueue: [
            CleanupCandidate(
                fileNode: node,
                classification: RuleEngine().classify(node),
                estimatedRecoverableBytes: 1,
                action: .queueForFutureTrash
            )
        ])

        let appState = AppState(sessionStore: store)
        appState.rootNode = FileNode(
            url: selectedRoot,
            isDirectory: true,
            logicalSize: 1,
            allocatedSize: 1,
            children: [node]
        )
        appState.cleanupQueue = [
            CleanupCandidate(
                fileNode: node,
                classification: RuleEngine().classify(node),
                estimatedRecoverableBytes: 1,
                action: .queueForFutureTrash
            )
        ]

        appState.forgetSavedSession()

        XCTAssertNil(store.load())
        XCTAssertNil(appState.rootNode)
        XCTAssertTrue(appState.cleanupQueue.isEmpty)
    }
}
