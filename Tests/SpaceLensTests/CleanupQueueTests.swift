import Foundation
import XCTest
@testable import SpaceLens

@MainActor
final class CleanupQueueTests: XCTestCase {
    func testQueueProjectionAddsQueueableCandidate() {
        let appState = AppState()
        let node = FileNode(
            url: URL(fileURLWithPath: "/Users/s1kor/dev/app/build"),
            isDirectory: true,
            logicalSize: 500,
            allocatedSize: 700
        )

        appState.addToCleanupQueue(node: node)

        XCTAssertEqual(appState.cleanupQueue.count, 1)
        XCTAssertEqual(appState.projectedRecoverableBytes, 700)
    }

    func testQueueRejectsValuableCandidate() {
        let appState = AppState()
        let node = FileNode(
            url: URL(fileURLWithPath: "/Users/s1kor/.lmstudio/models/model"),
            isDirectory: true,
            logicalSize: 500,
            allocatedSize: 700
        )

        appState.addToCleanupQueue(node: node)

        XCTAssertEqual(appState.cleanupQueue.count, 0)
        XCTAssertNotNil(appState.latestError)
    }

    func testDeleteForeverRejectsNonQueueableCandidate() async {
        let appState = AppState()
        let node = FileNode(
            url: URL(fileURLWithPath: "/Users/s1kor/.lmstudio/models/model"),
            isDirectory: true,
            logicalSize: 500,
            allocatedSize: 700
        )

        await appState.deleteForever(node: node)

        XCTAssertNotNil(appState.latestError)
        XCTAssertTrue(appState.cleanupInProgressIDs.isEmpty)
    }

    func testDeleteForeverRemovesQueueableCandidateFromDiskAndState() async throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceLensCleanupTests-\(UUID().uuidString)", isDirectory: true)
        let buildDirectory = temporaryRoot.appendingPathComponent(".build", isDirectory: true)
        try FileManager.default.createDirectory(at: buildDirectory, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: buildDirectory.appendingPathComponent("artifact.o"))
        defer {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }

        let buildNode = FileNode(
            url: buildDirectory,
            isDirectory: true,
            logicalSize: 3,
            allocatedSize: 3
        )
        let rootNode = FileNode(
            url: temporaryRoot,
            isDirectory: true,
            logicalSize: 3,
            allocatedSize: 3,
            children: [buildNode]
        )
        let appState = AppState()
        appState.rootNode = rootNode
        appState.selectedNodeID = buildNode.id
        appState.addToCleanupQueue(node: buildNode)

        await appState.deleteForever(node: buildNode)

        XCTAssertFalse(FileManager.default.fileExists(atPath: buildDirectory.path))
        XCTAssertNil(appState.rootNode?.find(id: buildNode.id))
        XCTAssertNil(appState.selectedNodeID)
        XCTAssertTrue(appState.cleanupQueue.isEmpty)
        XCTAssertTrue(appState.cleanupInProgressIDs.isEmpty)
        XCTAssertNotNil(appState.cleanupStatusMessage)
        XCTAssertNil(appState.latestError)
    }

    func testDeleteForeverPublishesCleanupProgress() async throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceLensCleanupProgressTests-\(UUID().uuidString)", isDirectory: true)
        let buildDirectory = temporaryRoot.appendingPathComponent(".build", isDirectory: true)
        try FileManager.default.createDirectory(at: buildDirectory, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 128).write(to: buildDirectory.appendingPathComponent("a.o"))
        try Data(repeating: 2, count: 256).write(to: buildDirectory.appendingPathComponent("b.o"))
        defer {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }

        let recorder = CleanupProgressRecorder()
        try await FileCleanupService.deleteForever(url: buildDirectory) { progress in
            recorder.record(progress)
        }
        let progressEvents = recorder.events

        XCTAssertFalse(FileManager.default.fileExists(atPath: buildDirectory.path))
        XCTAssertTrue(progressEvents.contains { $0.phase == .deleting })
        XCTAssertEqual(progressEvents.last?.phase, .finished)
        XCTAssertGreaterThanOrEqual(progressEvents.last?.completedItemCount ?? 0, 3)
        XCTAssertEqual(progressEvents.last?.completedItemCount, progressEvents.last?.totalItemCount)
    }

    func testSearchFilterAndSelectCleanupReadyVisible() {
        let appState = AppState()
        let cacheNode = FileNode(
            url: URL(fileURLWithPath: "/Users/s1kor/dev/app/build"),
            isDirectory: true,
            logicalSize: 1_000,
            allocatedSize: 1_000
        )
        let sourceNode = FileNode(
            url: URL(fileURLWithPath: "/Users/s1kor/dev/app/main.swift"),
            isDirectory: false,
            logicalSize: 2_000,
            allocatedSize: 2_000
        )
        appState.rootNode = FileNode(
            url: URL(fileURLWithPath: "/Users/s1kor/dev/app"),
            isDirectory: true,
            logicalSize: 3_000,
            allocatedSize: 3_000,
            children: [cacheNode, sourceNode]
        )

        appState.searchText = "build"
        XCTAssertEqual(appState.visibleNodes.map(\.node.id), [cacheNode.id])

        appState.searchText = ""
        appState.tableFilter = .cleanupReady
        XCTAssertEqual(appState.visibleNodes.map(\.node.id), [cacheNode.id])

        appState.tableFilter = .all
        appState.selectCleanupReadyVisible()

        XCTAssertEqual(appState.selectedNodeIDs, [cacheNode.id])
        XCTAssertEqual(appState.selectedRecoverableBytes, 1_000)
    }

    func testCachedVisibleNodesUpdateForSidebarFilterAndQueue() {
        let appState = AppState()
        let cacheNode = FileNode(
            url: URL(fileURLWithPath: "/Users/s1kor/dev/app/.build"),
            isDirectory: true,
            logicalSize: 1_000,
            allocatedSize: 1_000
        )
        let sourceNode = FileNode(
            url: URL(fileURLWithPath: "/Users/s1kor/dev/app/main.swift"),
            isDirectory: false,
            logicalSize: 2_000,
            allocatedSize: 2_000
        )
        appState.rootNode = FileNode(
            url: URL(fileURLWithPath: "/Users/s1kor/dev/app"),
            isDirectory: true,
            logicalSize: 3_000,
            allocatedSize: 3_000,
            children: [cacheNode, sourceNode]
        )

        XCTAssertEqual(appState.visibleNodes.map(\.node.id), [cacheNode.id, sourceNode.id])
        XCTAssertEqual(appState.visibleCleanupReadyCount, 1)

        appState.sidebarSelection = .safe
        XCTAssertEqual(appState.visibleNodes.map(\.node.id), [cacheNode.id])

        appState.sidebarSelection = .queue
        XCTAssertTrue(appState.visibleNodes.isEmpty)

        appState.addToCleanupQueue(node: cacheNode)
        XCTAssertEqual(appState.visibleNodes.map(\.node.id), [cacheNode.id])
    }

    func testSelectAllAndPruneSelectionToVisibleFilter() {
        let appState = AppState()
        let cacheNode = FileNode(
            url: URL(fileURLWithPath: "/Users/s1kor/dev/app/build"),
            isDirectory: true,
            logicalSize: 1_000,
            allocatedSize: 1_000
        )
        let sourceNode = FileNode(
            url: URL(fileURLWithPath: "/Users/s1kor/dev/app/main.swift"),
            isDirectory: false,
            logicalSize: 2_000,
            allocatedSize: 2_000
        )
        appState.rootNode = FileNode(
            url: URL(fileURLWithPath: "/Users/s1kor/dev/app"),
            isDirectory: true,
            logicalSize: 3_000,
            allocatedSize: 3_000,
            children: [cacheNode, sourceNode]
        )

        appState.selectAllVisible()
        XCTAssertEqual(appState.selectedNodeIDs, [cacheNode.id, sourceNode.id])

        appState.searchText = "main.swift"
        appState.pruneSelectionToVisible()

        XCTAssertEqual(appState.selectedNodeIDs, [sourceNode.id])
    }
}

private final class CleanupProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [CleanupProgress] = []

    var events: [CleanupProgress] {
        lock.lock()
        defer {
            lock.unlock()
        }
        return storage
    }

    func record(_ progress: CleanupProgress) {
        lock.lock()
        storage.append(progress)
        lock.unlock()
    }
}
