import AppKit
import XCTest
@testable import SpaceLens

@MainActor
final class CleanupNavigationTests: XCTestCase {
    private func node(_ name: String, size: Int64 = 1, children: [FileNode] = []) -> FileNode {
        FileNode(url: URL(fileURLWithPath: "/private/tmp/Navigation/\(name)"), isDirectory: !children.isEmpty,
            logicalSize: size, allocatedSize: size, children: children, captureIdentity: false)
    }
    private func row(_ node: FileNode, depth: Int = 1) -> NativeFileTableRow {
        NativeFileTableRow(item: FlattenedFileNode(node: node, depth: depth), classification: RuleEngine().classify(node))
    }
    private func apply(_ rows: [NativeFileTableRow], to coordinator: NativeFileTableView.Coordinator,
                       version: Int = 1, selected: Set<UUID> = [], hierarchy: Bool = true) {
        coordinator.apply(rows: rows, rowsVersion: version, selectedNodeIDs: selected, queuedNodeIDs: [],
            configuration: NativeFileTableConfiguration(layout: FileTableLayout(width: 980)),
            sort: NativeFileTableSort(key: .size, order: .reverse), showsHierarchy: hierarchy)
    }

    func testNativeOutlineSortsSiblingsAndPreservesExpansionAcrossReloads() throws {
        let leaf = node("parent/child/leaf", size: 100)
        let child = node("parent/child", size: 200, children: [leaf])
        let parent = node("parent", size: 300, children: [child])
        let sibling = node("sibling", size: 250)
        let coordinator = NativeFileTableView.Coordinator(onSelectionChange: { _ in }, onSortChange: { _ in })
        let scroll = coordinator.makeScrollView()
        scroll.frame = NSRect(x: 0, y: 0, width: 980, height: 320)
        let rows = [row(parent), row(sibling), row(child, depth: 2), row(leaf, depth: 3)]
        apply(rows, to: coordinator)
        let outline = try XCTUnwrap(coordinator.nativeTableView as? NSOutlineView)
        XCTAssertEqual(outline.numberOfRows, 3) // parent, child, sibling; leaf hidden
        let parentItem = try XCTUnwrap(outline.item(atRow: 0))
        let childItem = try XCTUnwrap(outline.item(atRow: 1))
        XCTAssertEqual(outline.level(forItem: parentItem), 0)
        XCTAssertEqual(outline.level(forItem: childItem), 1)
        outline.expandItem(childItem)
        XCTAssertEqual(outline.numberOfRows, 4)
        apply(rows, to: coordinator, version: 2, selected: [leaf.id])
        XCTAssertTrue(outline.item(atRow: 1) as AnyObject === childItem as AnyObject)
        XCTAssertTrue(outline.isItemExpanded(childItem))
        XCTAssertEqual(outline.selectedRowIndexes, IndexSet(integer: 2))
        outline.collapseItem(parentItem)
        XCTAssertEqual(outline.numberOfRows, 2)
    }

    func testCollapseReportsOnlyDisplayedIDsAndSelectionDoesNotIncludeHiddenDescendants() throws {
        let child = node("parent/child")
        let parent = node("parent", children: [child])
        let state = AppState(requiresSecurityScopedAccess: false)
        state.rootNode = node("root", children: [parent])
        let coordinator = NativeFileTableView.Coordinator(onSelectionChange: { state.selectedNodeIDs = $0 }, onSortChange: { _ in })
        coordinator.onDisplayedNodesChange = { ids, available in state.setDisplayedNodeIDs(ids, matching: available) }
        _ = coordinator.makeScrollView()
        apply([row(parent), row(child, depth: 2)], to: coordinator)
        let outline = try XCTUnwrap(coordinator.nativeTableView as? NSOutlineView)
        outline.collapseItem(outline.item(atRow: 0))
        state.selectAllVisible()
        XCTAssertEqual(state.selectedNodeIDs, [parent.id])
        XCTAssertEqual(state.displayedNodeIDs, [parent.id])
        apply([row(parent), row(child, depth: 2)], to: coordinator, version: 2, hierarchy: false)
        XCTAssertEqual(outline.numberOfRows, 2)
        XCTAssertFalse(outline.isExpandable(outline.item(atRow: 0)))
    }

    func testSummaryNavigationClearsStaleFiltersAndConservativeMatchesNormalizedRoots() {
        let cache = "/Users/example/Library/Application Support/com.apple.wallpaper/aerials/videos"
        let leaf = FileNode(url: URL(fileURLWithPath: cache + "/clip.mov"), isDirectory: false,
            logicalSize: 1, allocatedSize: 1, captureIdentity: false)
        let parent = FileNode(url: URL(fileURLWithPath: cache), isDirectory: true,
            logicalSize: 1, allocatedSize: 1, children: [leaf], captureIdentity: false)
        let state = AppState(requiresSecurityScopedAccess: false)
        state.rootNode = node("root", children: [parent])
        state.searchText = "no match"
        state.tableFilter = .files
        state.selectedNodeIDs = [leaf.id]
        state.showSummary(.safe)
        XCTAssertEqual(state.searchText, "")
        XCTAssertEqual(state.tableFilter, .all)
        XCTAssertTrue(state.selectedNodeIDs.isEmpty)
        let candidates = state.rootNode!.flattened().dropFirst().filter { state.classification(for: $0.node).level.isQueueable }
        XCTAssertEqual(state.visibleNodes.map(\.id), [parent.id])
        XCTAssertEqual(state.visibleNodes.map(\.id), CleanupTargetNormalizer.collapsingDescendants(Array(candidates), url: { $0.node.url }).map(\.id))
    }

    func testTheoreticalPredicateKeepsToolManagedCandidatesDistinctFromCleanupPermission() {
        let node = node("cache")
        for (level, kind, expected) in [(SafetyLevel.activeOrInUse, ScanKind.packageCache, true),
                                       (.systemCritical, .packageCache, false), (.largeButValuable, .userHistory, false),
                                       (.unknownReview, .rebuildableCache, true), (.safeTemp, .temp, true)] {
            let classification = SafetyClassification(level: level, confidence: 1, category: "test", summary: "test",
                evidence: [], recommendedAction: "Review", kind: kind)
            XCTAssertEqual(CleanupRecoveryPolicy.countsTowardTheoreticalRecovery(node: node, classification: classification), expected)
            if level == .activeOrInUse { XCTAssertFalse(classification.level.isQueueable) }
        }
    }

    func testAdditionalFilesOutsideScanAreQueuedWithoutChangingTotalsOrAllowingUnreviewedMove() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("SpaceLensNavigation-\(UUID())").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: base.appendingPathComponent("scanned"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = base.appendingPathComponent("outside.txt")
        try Data("manual review".utf8).write(to: file)
        let state = AppState(activitySnapshot: { .empty }, requiresSecurityScopedAccess: false)
        state.startScan(root: base.appendingPathComponent("scanned"))
        for _ in 0..<500 where state.isScanning { try await Task.sleep(for: .milliseconds(10)) }
        let original = try XCTUnwrap(state.scanStatistics)
        await state.addAdditionalFiles([file, file])
        XCTAssertEqual(state.cleanupQueue.count, 1)
        XCTAssertEqual(state.sidebarSelection, .queue)
        XCTAssertEqual(state.scanStatistics, original)
        XCTAssertEqual(state.selectedCleanupEligibleNodes.count, 1)
        await state.moveSelectedToBin()
        XCTAssertNotNil(state.latestError) // manual approval was not provided
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testForgetAndRootChangeDiscardAdditionalChooserTargets() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("SpaceLensNavigation-\(UUID())").resolvingSymlinksInPath()
        for name in ["A", "B"] { try FileManager.default.createDirectory(at: base.appendingPathComponent(name), withIntermediateDirectories: true) }
        defer { try? FileManager.default.removeItem(at: base) }
        let file = base.appendingPathComponent("outside.txt")
        try Data("keep".utf8).write(to: file)
        for forget in [true, false] {
            let state = AppState(activitySnapshot: { .empty }, requiresSecurityScopedAccess: false)
            state.startScan(root: base.appendingPathComponent("A"))
            for _ in 0..<500 where state.isScanning { try await Task.sleep(for: .milliseconds(10)) }
            await state.addAdditionalFiles([file])
            XCTAssertEqual(state.cleanupQueue.count, 1)
            if forget { state.forgetSavedSession() }
            state.startScan(root: base.appendingPathComponent("B"))
            for _ in 0..<500 where state.isScanning { try await Task.sleep(for: .milliseconds(10)) }
            state.showSummary(.all)
            XCTAssertTrue(state.cleanupQueue.isEmpty)
            XCTAssertFalse(state.visibleNodes.contains { $0.node.url == file })
        }
    }

    func testChoosingReplacedRetainedFileRejectsStaleIdentityClearly() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("SpaceLensNavigation-\(UUID())").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = base.appendingPathComponent("retained.txt")
        try Data("old".utf8).write(to: file)
        let state = AppState(activitySnapshot: { .empty }, requiresSecurityScopedAccess: false)
        state.startScan(root: base)
        for _ in 0..<500 where state.isScanning { try await Task.sleep(for: .milliseconds(10)) }
        try FileManager.default.moveItem(at: file, to: base.appendingPathComponent("original.txt"))
        try Data("new inode".utf8).write(to: file)
        await state.addAdditionalFiles([file])
        XCTAssertTrue(state.cleanupQueue.isEmpty)
        XCTAssertTrue(state.latestError?.contains("changed since scan") == true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testBulkChooserTargetsAreNormalizedAsOneQueueBatch() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("SpaceLensNavigation-\(UUID())").resolvingSymlinksInPath()
        let scanned = base.appendingPathComponent("scanned")
        try FileManager.default.createDirectory(at: scanned, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let files = (0..<100).map { base.appendingPathComponent("file\($0).txt") }
        for file in files { try Data("fixture".utf8).write(to: file) }
        let state = AppState(activitySnapshot: { .empty }, requiresSecurityScopedAccess: false)
        state.startScan(root: scanned)
        for _ in 0..<500 where state.isScanning { try await Task.sleep(for: .milliseconds(10)) }
        let retained = (0..<10_000).map { index in
            FileNode(url: scanned.appendingPathComponent("retained\(index)"), isDirectory: false,
                logicalSize: 1, allocatedSize: 1, captureIdentity: false)
        }
        state.rootNode = FileNode(url: scanned, isDirectory: true, logicalSize: 10_000,
            allocatedSize: 10_000, children: retained)
        let started = ContinuousClock.now
        await state.addAdditionalFiles(files + files)
        print("Add Files benchmark: 100 targets against 10000 retained nodes, \(started.duration(to: .now))")
        XCTAssertEqual(state.cleanupQueue.count, 100)
        XCTAssertEqual(state.selectedCleanupEligibleNodes.count, 100)
    }

    func testAdditionalFilesRejectSymlinksAndUnavailableActivity() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("SpaceLensNavigation-\(UUID())").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = base.appendingPathComponent("outside.txt")
        let link = base.appendingPathComponent("link")
        try Data("keep".utf8).write(to: file)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        let state = AppState(activitySnapshot: { .empty }, requiresSecurityScopedAccess: false)
        state.startScan(root: base)
        for _ in 0..<500 where state.isScanning { try await Task.sleep(for: .milliseconds(10)) }
        await state.addAdditionalFiles([link, URL(fileURLWithPath: "/System")])
        XCTAssertTrue(state.cleanupQueue.isEmpty)
        XCTAssertNotNil(state.latestError)
        let unavailable = AppState(activitySnapshot: {
            PathUseSnapshot(runningToolLabels: [], xcodeFamilyActive: false, dockerActive: false, cursorActive: false,
                cargoActive: false, activityCheckError: "unavailable")
        }, requiresSecurityScopedAccess: false)
        unavailable.startScan(root: base)
        for _ in 0..<500 where unavailable.isScanning { try await Task.sleep(for: .milliseconds(10)) }
        await unavailable.addAdditionalFiles([file])
        XCTAssertTrue(unavailable.cleanupQueue.isEmpty)
    }
}
