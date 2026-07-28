import AppKit
import XCTest
@testable import SpaceLens

@MainActor
final class NativeFileTableLifecycleTests: XCTestCase {
    func testQueuedStateIsStoredBeforeTheNameCellReloads() {
        let row = makeRow(name: "queued.tmp")
        let coordinator = makeCoordinator()

        coordinator.apply(
            rows: [row],
            rowsVersion: 1,
            selectedNodeIDs: [],
            queuedNodeIDs: [],
            configuration: wideConfiguration,
            sort: sizeSort
        )
        coordinator.apply(
            rows: [row],
            rowsVersion: 1,
            selectedNodeIDs: [],
            queuedNodeIDs: [row.id],
            configuration: wideConfiguration,
            sort: sizeSort
        )

        XCTAssertTrue(nameCellLabel(from: coordinator, row: 0).contains("Queued for cleanup"))
    }

    func testDelegateSelectionReloadsNameCellAndPublishesTheNewIdentifier() {
        let row = makeRow(name: "selection.tmp")
        var publishedSelections: [Set<UUID>] = []
        let coordinator = makeCoordinator { publishedSelections.append($0) }
        coordinator.apply(
            rows: [row],
            rowsVersion: 1,
            selectedNodeIDs: [],
            queuedNodeIDs: [],
            configuration: wideConfiguration,
            sort: sizeSort
        )

        coordinator.nativeTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        coordinator.tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification))

        XCTAssertEqual(publishedSelections, [[row.id]])
        XCTAssertTrue(nameCellLabel(from: coordinator, row: 0).contains("Selected"))
    }

    func testRowsVersionReprojectsSelectionByIdentifierAfterReorder() {
        let first = makeRow(name: "first.tmp")
        let second = makeRow(name: "second.tmp")
        let coordinator = makeCoordinator()
        coordinator.apply(
            rows: [first, second],
            rowsVersion: 1,
            selectedNodeIDs: [second.id],
            queuedNodeIDs: [],
            configuration: wideConfiguration,
            sort: sizeSort
        )
        XCTAssertEqual(coordinator.nativeTableView.selectedRowIndexes, IndexSet(integer: 1))

        coordinator.apply(
            rows: [second, first],
            rowsVersion: 2,
            selectedNodeIDs: [second.id],
            queuedNodeIDs: [],
            configuration: wideConfiguration,
            sort: sizeSort
        )

        XCTAssertEqual(coordinator.nativeTableView.selectedRowIndexes, IndexSet(integer: 0))
    }

    func testColumnRebuildRestoresTheCurrentSortDescriptor() {
        let row = makeRow(name: "sort.tmp")
        let coordinator = makeCoordinator()
        let sort = NativeFileTableSort(key: .size, order: .reverse)
        coordinator.apply(
            rows: [row],
            rowsVersion: 1,
            selectedNodeIDs: [],
            queuedNodeIDs: [],
            configuration: wideConfiguration,
            sort: sort
        )
        coordinator.apply(
            rows: [row],
            rowsVersion: 1,
            selectedNodeIDs: [],
            queuedNodeIDs: [],
            configuration: NativeFileTableConfiguration(layout: FileTableLayout(width: 499)),
            sort: sort
        )

        XCTAssertEqual(coordinator.nativeTableView.sortDescriptors.first?.key, NativeFileTableColumnKind.size.rawValue)
        XCTAssertEqual(coordinator.nativeTableView.sortDescriptors.first?.ascending, false)
    }

    private var wideConfiguration: NativeFileTableConfiguration {
        NativeFileTableConfiguration(layout: FileTableLayout(width: 980))
    }

    private var sizeSort: NativeFileTableSort {
        NativeFileTableSort(key: .size, order: .reverse)
    }

    private func makeCoordinator(
        onSelectionChange: @escaping (Set<UUID>) -> Void = { _ in }
    ) -> NativeFileTableView.Coordinator {
        let coordinator = NativeFileTableView.Coordinator(
            onSelectionChange: onSelectionChange,
            onSortChange: { _ in }
        )
        let scrollView = coordinator.makeScrollView()
        scrollView.frame = NSRect(x: 0, y: 0, width: 980, height: 320)
        coordinator.nativeTableView.frame = scrollView.bounds
        return coordinator
    }

    private func nameCellLabel(from coordinator: NativeFileTableView.Coordinator, row: Int) -> String {
        coordinator.nativeTableView.layoutSubtreeIfNeeded()
        return coordinator.nativeTableView.view(atColumn: 0, row: row, makeIfNecessary: true)?.accessibilityLabel() ?? ""
    }

    private func makeRow(name: String) -> NativeFileTableRow {
        let node = FileNode(
            url: URL(fileURLWithPath: "/tmp/\\(name)"),
            isDirectory: false,
            logicalSize: 1,
            allocatedSize: 1
        )
        return NativeFileTableRow(
            item: FlattenedFileNode(node: node, depth: 8),
            classification: SafetyClassification(
                level: .safeTemp,
                confidence: 1,
                category: "Temporary",
                summary: "Test fixture",
                evidence: [],
                recommendedAction: "Queue"
            )
        )
    }
}
