import Foundation
import XCTest
@testable import SpaceLens

final class ManualCleanupTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("SpaceLensManual-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        root = root.resolvingSymlinksInPath()
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }
    private func fixture(_ path: String = "Users/example/Documents/valuable.txt") throws -> FileNode {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("keep unless deliberately reviewed".utf8).write(to: url)
        return FileNode(url: url, isDirectory: false, logicalSize: 33, allocatedSize: 33)
    }

    func testValuableFileRequiresExplicitReviewAndKnownActivity() throws {
        let node = try fixture()
        XCTAssertEqual(RuleEngine().classify(node).level, .largeButValuable)
        XCTAssertThrowsError(try FileCleanupService.validatedCleanupURL(for: node, authorizedRoot: root))
        XCTAssertThrowsError(try FileCleanupService.validatedCleanupURL(for: node, authorizedRoot: root, reviewedByUser: true))
        XCTAssertEqual(try FileCleanupService.validatedCleanupURL(for: node, authorizedRoot: root,
            reviewedByUser: true, pathUse: .empty), node.url.standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: node.path))
    }

    func testManualReviewCannotOverrideOpenPathsOrUnavailableActivity() throws {
        let node = try fixture("ordinary.txt")
        let open = PathUseSnapshot(runningToolLabels: [], xcodeFamilyActive: false, dockerActive: false,
            cursorActive: false, cargoActive: false, openPaths: [node.path])
        let unavailable = PathUseSnapshot(runningToolLabels: [], xcodeFamilyActive: false, dockerActive: false,
            cursorActive: false, cargoActive: false, activityCheckError: "unavailable")
        for activity in [open, unavailable] {
            XCTAssertThrowsError(try FileCleanupService.validatedCleanupURL(for: node, authorizedRoot: root,
                reviewedByUser: true, pathUse: activity))
        }
    }

    func testManualReviewRetainsIdentityScopeAndIncompleteScanGuards() throws {
        let node = try fixture()
        XCTAssertThrowsError(try FileCleanupService.validatedCleanupURL(for: node, authorizedRoot: node.url,
            reviewedByUser: true, pathUse: .empty))
        let incomplete = FileNode(url: node.url, isDirectory: false, logicalSize: 33, allocatedSize: 33, scanError: "denied")
        XCTAssertThrowsError(try FileCleanupService.validatedCleanupURL(for: incomplete, authorizedRoot: root,
            reviewedByUser: true, pathUse: .empty))
        let saved = node.url.appendingPathExtension("saved")
        try FileManager.default.moveItem(at: node.url, to: saved)
        try Data("replacement".utf8).write(to: node.url)
        XCTAssertThrowsError(try FileCleanupService.validatedCleanupURL(for: node, authorizedRoot: root,
            reviewedByUser: true, pathUse: .empty))
    }

    func testManualFolderRejectsProtectedDescendantEvenWhenDisplayChildrenAreEmpty() throws {
        _ = try fixture("archive/docker/volumes/important.bin")
        let folder = FileNode(url: root.appendingPathComponent("archive"), isDirectory: true, logicalSize: 33, allocatedSize: 33)
        XCTAssertThrowsError(try FileCleanupService.validatedCleanupURL(for: folder, authorizedRoot: root,
            reviewedByUser: true, pathUse: .empty))
    }

    func testManualReviewRejectsSymlinkAndSystemRoot() throws {
        let node = try fixture()
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: node.url)
        let symbolic = FileNode(url: link, isDirectory: false, isSymlink: true, logicalSize: 0, allocatedSize: 0)
        XCTAssertThrowsError(try FileCleanupService.validatedCleanupURL(for: symbolic, authorizedRoot: root,
            reviewedByUser: true, pathUse: .empty))
        let system = FileNode(url: URL(fileURLWithPath: "/System"), isDirectory: true, logicalSize: 0, allocatedSize: 0)
        XCTAssertEqual(RuleEngine().classify(system).level, .systemCritical)
        XCTAssertThrowsError(try FileCleanupService.validatedCleanupURL(for: system, authorizedRoot: URL(fileURLWithPath: "/"),
            reviewedByUser: true, pathUse: .empty))
    }

    @MainActor
    func testQueuedManualItemRestoresAsReviewRequiredAndUnacknowledgedCleanupStops() async throws {
        let node = try fixture("ordinary.txt")
        let store = AppSessionStore(fileURL: root.appendingPathComponent("session.json"))
        let first = AppState(sessionStore: store, activitySnapshot: { .empty }, requiresSecurityScopedAccess: false)
        first.startScan(root: root)
        for _ in 0..<200 where first.isScanning { try await Task.sleep(for: .milliseconds(10)) }
        let scanned = try XCTUnwrap(first.rootNode?.flattened().first { $0.node.url.resolvingSymlinksInPath() == node.url.resolvingSymlinksInPath() }?.node)
        first.addToCleanupQueue(node: scanned)
        let restored = AppState(sessionStore: store, restoreOnLaunch: true, activitySnapshot: { .empty }, requiresSecurityScopedAccess: false)
        restored.rescan()
        for _ in 0..<200 where restored.isScanning { try await Task.sleep(for: .milliseconds(10)) }
        let queued = try XCTUnwrap(restored.cleanupQueue.first)
        XCTAssertEqual(queued.classification.level, .unknownReview)
        await restored.moveToBin(nodes: [queued.fileNode])
        XCTAssertNotNil(restored.latestError)
        XCTAssertTrue(FileManager.default.fileExists(atPath: node.path))
    }

    func testSimulatorDeviceStateCannotBeManuallyOverriddenWithoutInventory() throws {
        let node = try fixture("Library/Developer/CoreSimulator/Devices/device/data/state.txt")
        XCTAssertEqual(RuleEngine().classify(node).kind, .simulator)
        XCTAssertThrowsError(try FileCleanupService.validatedCleanupURL(for: node, authorizedRoot: root,
            reviewedByUser: true, pathUse: .empty))
        let parent = FileNode(url: root.appendingPathComponent("Library"), isDirectory: true, logicalSize: 33, allocatedSize: 33)
        XCTAssertThrowsError(try FileCleanupService.validatedCleanupURL(for: parent, authorizedRoot: root,
            reviewedByUser: true, pathUse: .empty))
    }

    func testManualActivityRefreshCannotReuseAutomaticBatchSnapshot() async {
        let changed = PathUseDetector.snapshot(runningProcessNames: ["cargo"], openPaths: [])
        let cache = CleanupActivityRefresh(initial: .empty, provider: { changed })
        let recent = await cache.snapshot(forceRefresh: false)
        XCTAssertFalse(recent.cargoActive)
        let manual = await cache.snapshot(forceRefresh: true)
        XCTAssertTrue(manual.cargoActive)
    }

    func testFinalActivityRefreshAfterManualPreflightRejectsNewOpenFileOrTool() async throws {
        let node = try fixture("final-check.txt")
        let open = PathUseSnapshot(runningToolLabels: [], xcodeFamilyActive: false, dockerActive: false,
            cursorActive: false, cargoActive: false, openPaths: [node.path])
        let newTool = PathUseDetector.snapshot(runningProcessNames: ["node"], openPaths: [])
        for fresh in [open, newTool] {
            do {
                _ = try await FileCleanupService.moveToBin(node: node, authorizedRoot: root,
                    reviewedByUser: true, pathUse: .empty, activitySnapshot: { fresh })
                XCTFail("A newly opened file or started tool must stop a reviewed move")
            } catch {
                XCTAssertTrue(FileManager.default.fileExists(atPath: node.path))
            }
        }
    }

    @MainActor
    func testPartialBatchFailureRemainsVisibleAfterLaterSuccess() async throws {
        _ = try fixture("blocked/docker/volumes/important.bin")
        let removable = try fixture("removable-\(UUID().uuidString).txt")
        let state = AppState(activitySnapshot: { .empty }, requiresSecurityScopedAccess: false)
        state.startScan(root: root)
        for _ in 0..<200 where state.isScanning { try await Task.sleep(for: .milliseconds(10)) }
        let blocked = try XCTUnwrap(state.rootNode?.children.first { $0.name == "blocked" })
        let good = try XCTUnwrap(state.rootNode?.flattened().first { $0.node.url.resolvingSymlinksInPath() == removable.url.resolvingSymlinksInPath() }?.node)
        await state.moveToBin(nodes: [blocked, good], reviewedByUser: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: blocked.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: good.path))
        XCTAssertTrue(state.latestError?.contains("Cleanup failed for blocked") == true)
        XCTAssertTrue(state.cleanupStatusMessage?.contains("1 items") == true)
    }

    func testActiveManualFolderStopsBeforeContentsInspectionEvenIfToolWouldCloseLater() async throws {
        let child = try fixture("active-folder/ordinary.txt")
        let node = FileNode(url: child.url.deletingLastPathComponent(), isDirectory: true, logicalSize: 33, allocatedSize: 33)
        let open = PathUseSnapshot(runningToolLabels: [], xcodeFamilyActive: false, dockerActive: false,
            cursorActive: false, cargoActive: false, openPaths: [child.path])
        let probes = ManualProbeCounter(first: open)
        let progress = ManualCheckingRecorder()
        do {
            _ = try await FileCleanupService.moveToBin(node: node, authorizedRoot: root, reviewedByUser: true,
                pathUse: .empty, activitySnapshot: { await probes.snapshot() }, progress: { progress.record($0) })
            XCTFail("Activity at the start of folder inspection must stop cleanup")
        } catch {
            XCTAssertTrue(FileManager.default.fileExists(atPath: child.path))
        }
        let count = await probes.count
        XCTAssertEqual(count, 1)
        XCTAssertFalse(progress.didCheckContents)
    }

    func testManualFolderRequiresFreshActivityBeforeAndAfterInspection() async throws {
        _ = try fixture("folder/ordinary.txt")
        let node = FileNode(url: root.appendingPathComponent("folder"), isDirectory: true, logicalSize: 33, allocatedSize: 33)
        let probes = ManualProbeCounter()
        _ = try await FileCleanupService.moveToBin(node: node, authorizedRoot: root, reviewedByUser: true,
            pathUse: .empty, activitySnapshot: { await probes.snapshot() })
        let count = await probes.count
        XCTAssertEqual(count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: node.path))
    }

    @MainActor
    func testManualMoveUsesOneFinalProbeAndPersistsUpdatedQueue() async throws {
        let node = try fixture("single-probe-\(UUID().uuidString).txt")
        let store = AppSessionStore(fileURL: root.appendingPathComponent("session.json"))
        let probes = ManualProbeCounter()
        let state = AppState(sessionStore: store, activitySnapshot: { await probes.snapshot() }, requiresSecurityScopedAccess: false)
        state.startScan(root: root)
        for _ in 0..<200 where state.isScanning { try await Task.sleep(for: .milliseconds(10)) }
        let scanned = try XCTUnwrap(state.rootNode?.flattened().first { $0.node.url.resolvingSymlinksInPath() == node.url.resolvingSymlinksInPath() }?.node)
        state.addToCleanupQueue(node: scanned)
        XCTAssertEqual(store.load()?.cleanupPaths.count, 1)
        await state.moveToBin(nodes: [scanned], reviewedByUser: true)
        let count = await probes.count
        XCTAssertEqual(count, 1)
        XCTAssertNil(state.latestError)
        XCTAssertEqual(store.load()?.cleanupPaths, [])
        XCTAssertEqual(state.estimatedMovedToBinBytes, scanned.effectiveSize)
    }

    @MainActor
    func testExplicitReviewMovesOrdinaryFixtureToBin() async throws {
        let node = try fixture("reviewed-\(UUID().uuidString).txt")
        let state = AppState(activitySnapshot: { .empty }, requiresSecurityScopedAccess: false)
        state.startScan(root: root)
        for _ in 0..<200 where state.isScanning { try await Task.sleep(for: .milliseconds(10)) }
        let scanned = try XCTUnwrap(state.rootNode?.flattened().first { $0.node.url.resolvingSymlinksInPath() == node.url.resolvingSymlinksInPath() }?.node)
        state.selectedNodeIDs = [scanned.id]
        await state.moveToBin(nodes: [scanned], reviewedByUser: true)
        XCTAssertNil(state.latestError)
        XCTAssertFalse(FileManager.default.fileExists(atPath: node.path))
        XCTAssertTrue(state.cleanupStatusMessage?.contains("Moved to Bin") == true)
        XCTAssertEqual(state.estimatedMovedToBinBytes, scanned.effectiveSize)
    }

    @MainActor
    func testQueueSupportsManualItemsWithoutReclassifyingThemSafeAndRescanKeepsMode() async throws {
        let node = try fixture()
        _ = try fixture("ordinary.txt")
        let state = AppState(activitySnapshot: { .empty }, requiresSecurityScopedAccess: false)
        state.startScan(root: root)
        for _ in 0..<200 where state.isScanning { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(state.isScanning)
        let scanned = try XCTUnwrap(state.rootNode?.flattened().first { $0.node.url.resolvingSymlinksInPath() == node.url.resolvingSymlinksInPath() }?.node)
        state.selectedNodeIDs = [scanned.id]
        XCTAssertEqual(state.selectedCleanupEligibleNodes.map(\.path), [scanned.path])
        state.addSelectedToCleanupQueue()
        XCTAssertEqual(state.cleanupQueue.map(\.classification.level), [.largeButValuable])
        state.rescan()
        for _ in 0..<200 where state.isScanning { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(state.cleanupQueue.map { $0.fileNode.url.resolvingSymlinksInPath() }, [node.url.resolvingSymlinksInPath()])
        state.startSmartScan(root: root)
        for _ in 0..<200 where state.isScanning { try await Task.sleep(for: .milliseconds(10)) }
        state.rescan()
        XCTAssertEqual(state.scanMode, .smart)
        state.cancelScan()
    }
}

private actor ManualProbeCounter {
    private(set) var count = 0
    private let first: PathUseSnapshot
    init(first: PathUseSnapshot = .empty) { self.first = first }
    func snapshot() -> PathUseSnapshot { count += 1; return count == 1 ? first : .empty }
}

private final class ManualCheckingRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var checked = false
    var didCheckContents: Bool { lock.lock(); defer { lock.unlock() }; return checked }
    func record(_ progress: CleanupProgress) {
        lock.lock(); defer { lock.unlock() }
        if progress.phase == .checking { checked = true }
    }
}
