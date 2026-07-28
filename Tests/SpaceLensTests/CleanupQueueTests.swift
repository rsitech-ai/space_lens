import Combine
import Foundation
import XCTest
@testable import SpaceLens

@MainActor
final class CleanupQueueTests: XCTestCase {
    func testQueueMembershipUpdatesAfterAddAndRemoval() throws {
        let appState = AppState()
        let node = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/.build"),
            isDirectory: true,
            logicalSize: 500,
            allocatedSize: 700
        )

        XCTAssertFalse(appState.isQueued(node: node))

        appState.addToCleanupQueue(node: node)
        XCTAssertTrue(appState.isQueued(node: node))

        let candidate = try XCTUnwrap(appState.cleanupQueue.first)
        appState.removeFromCleanupQueue(candidate)
        XCTAssertFalse(appState.isQueued(node: node))
    }

    func testQueueMembershipDropsDescendantWhenParentReplacesIt() {
        let artifact = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/.build/artifact.o"),
            isDirectory: false,
            logicalSize: 400,
            allocatedSize: 400
        )
        let build = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/.build"),
            isDirectory: true,
            logicalSize: 400,
            allocatedSize: 400,
            children: [artifact]
        )
        let appState = AppState()

        appState.addToCleanupQueue(node: artifact)
        XCTAssertTrue(appState.isQueued(node: artifact))

        appState.addToCleanupQueue(node: build)
        XCTAssertTrue(appState.isQueued(node: build))
        XCTAssertFalse(appState.isQueued(node: artifact))
    }

    func testQueueProjectionAddsQueueableCandidate() {
        let appState = AppState()
        let node = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/.build"),
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
            url: URL(fileURLWithPath: "/Users/example/.lmstudio/models/model"),
            isDirectory: true,
            logicalSize: 500,
            allocatedSize: 700
        )

        appState.addToCleanupQueue(node: node)

        XCTAssertEqual(appState.cleanupQueue.count, 0)
        XCTAssertNotNil(appState.latestError)
    }

    func testSearchFilterAndSelectCleanupReadyVisible() {
        let appState = AppState()
        let cacheNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/.build"),
            isDirectory: true,
            logicalSize: 1_000,
            allocatedSize: 1_000
        )
        let sourceNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/main.swift"),
            isDirectory: false,
            logicalSize: 2_000,
            allocatedSize: 2_000
        )
        appState.rootNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp"),
            isDirectory: true,
            logicalSize: 3_000,
            allocatedSize: 3_000,
            children: [cacheNode, sourceNode]
        )

        appState.searchText = ".build"
        XCTAssertEqual(appState.visibleNodes.map(\.node.id), [cacheNode.id])

        appState.searchText = ""
        appState.tableFilter = .cleanupReady
        XCTAssertEqual(appState.visibleNodes.map(\.node.id), [cacheNode.id])

        appState.tableFilter = .all
        appState.selectCleanupReadyVisible()

        XCTAssertEqual(appState.selectedNodeIDs, [cacheNode.id])
        XCTAssertEqual(appState.selectedRecoverableBytes, 1_000)
    }

    func testCleanupSelectionCollapsesDescendantsWhenParentIsSelected() {
        let appState = AppState()
        let artifactNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/.build/artifact.o"),
            isDirectory: false,
            logicalSize: 400,
            allocatedSize: 400
        )
        let buildNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/.build"),
            isDirectory: true,
            logicalSize: 400,
            allocatedSize: 400,
            children: [artifactNode]
        )
        appState.rootNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp"),
            isDirectory: true,
            logicalSize: 400,
            allocatedSize: 400,
            children: [buildNode]
        )

        appState.selectedNodeIDs = [buildNode.id, artifactNode.id]

        XCTAssertEqual(appState.selectedCleanupEligibleNodes.map(\.id), [buildNode.id])
        XCTAssertEqual(appState.selectedRecoverableBytes, 400)
    }

    func testSelectingCleanupReadyRowsPublishesOneStateChange() {
        let appState = AppState()
        let cacheNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/.build"),
            isDirectory: true,
            logicalSize: 1_000,
            allocatedSize: 1_000
        )
        let sourceNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/main.swift"),
            isDirectory: false,
            logicalSize: 1_000,
            allocatedSize: 1_000
        )
        appState.rootNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp"),
            isDirectory: true,
            logicalSize: 2_000,
            allocatedSize: 2_000,
            children: [cacheNode, sourceNode]
        )
        appState.selectedNodeIDs = [cacheNode.id, sourceNode.id]
        var publishedChangeCount = 0
        let subscription = appState.objectWillChange.sink {
            publishedChangeCount += 1
        }

        appState.selectCleanupReadyVisible()

        XCTAssertEqual(publishedChangeCount, 1)
        XCTAssertEqual(appState.selectedCleanupEligibleNodes.map(\.id), [cacheNode.id])
        XCTAssertEqual(appState.selectedRecoverableBytes, 1_000)
        withExtendedLifetime(subscription) {}
    }

    func testProjectionMutationsPublishOneStateChangeEach() {
        let appState = AppState()
        let cacheNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/.build"),
            isDirectory: true,
            logicalSize: 1_000,
            allocatedSize: 1_000
        )
        appState.rootNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp"),
            isDirectory: true,
            logicalSize: 1_000,
            allocatedSize: 1_000,
            children: [cacheNode]
        )
        appState.selectedNodeIDs = [cacheNode.id]
        var publishedChangeCount = 0
        let subscription = appState.objectWillChange.sink {
            publishedChangeCount += 1
        }

        appState.searchText = ".build"
        XCTAssertEqual(publishedChangeCount, 1)
        XCTAssertEqual(appState.selectedNodeIDs, [cacheNode.id])

        publishedChangeCount = 0
        appState.tableFilter = .cleanupReady
        XCTAssertEqual(publishedChangeCount, 1)

        publishedChangeCount = 0
        appState.sidebarSelection = .safe
        XCTAssertEqual(publishedChangeCount, 1)

        publishedChangeCount = 0
        appState.addToCleanupQueue(node: cacheNode)
        XCTAssertEqual(publishedChangeCount, 1)
        withExtendedLifetime(subscription) {}
    }

    func testBulkQueuePublishesOneQueueMutationInsteadOfOnePerSelectedItem() {
        let cacheNodes = (0..<64).map { index in
            FileNode(
                url: URL(fileURLWithPath: "/Users/example/Projects/Project-\(index)/.build"),
                isDirectory: true,
                logicalSize: 1_000,
                allocatedSize: 1_000
            )
        }
        let appState = AppState()
        appState.rootNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects"),
            isDirectory: true,
            logicalSize: 64_000,
            allocatedSize: 64_000,
            children: cacheNodes
        )
        appState.selectedNodeIDs = Set(cacheNodes.map(\.id))
        var publishedChangeCount = 0
        let subscription = appState.objectWillChange.sink {
            publishedChangeCount += 1
        }

        appState.addSelectedToCleanupQueue()

        XCTAssertEqual(appState.cleanupQueue.count, 64)
        XCTAssertEqual(
            publishedChangeCount,
            2,
            "Bulk queueing should publish once for the queue and once for its status, regardless of selection size"
        )
        withExtendedLifetime(subscription) {}
    }

    func testQueueReplacesDescendantWithSelectedParent() {
        let appState = AppState()
        let artifactNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/.build/artifact.o"),
            isDirectory: false,
            logicalSize: 400,
            allocatedSize: 400
        )
        let buildNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/.build"),
            isDirectory: true,
            logicalSize: 400,
            allocatedSize: 400,
            children: [artifactNode]
        )

        appState.addToCleanupQueue(node: artifactNode)
        appState.addToCleanupQueue(node: buildNode)

        XCTAssertEqual(appState.cleanupQueue.map(\.fileNode.id), [buildNode.id])
        XCTAssertEqual(appState.projectedRecoverableBytes, 400)
    }

    func testCachedVisibleNodesUpdateForSidebarFilterAndQueue() {
        let appState = AppState()
        let cacheNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/.build"),
            isDirectory: true,
            logicalSize: 1_000,
            allocatedSize: 1_000
        )
        let sourceNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/main.swift"),
            isDirectory: false,
            logicalSize: 2_000,
            allocatedSize: 2_000
        )
        appState.rootNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp"),
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
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/.build"),
            isDirectory: true,
            logicalSize: 1_000,
            allocatedSize: 1_000
        )
        let sourceNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp/main.swift"),
            isDirectory: false,
            logicalSize: 2_000,
            allocatedSize: 2_000
        )
        appState.rootNode = FileNode(
            url: URL(fileURLWithPath: "/Users/example/Projects/SampleApp"),
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
