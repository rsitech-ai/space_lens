import XCTest
@testable import SpaceLens

final class NativeFileTableConfigurationTests: XCTestCase {
    func testConfigurationKeepsTheExistingResponsiveColumnSetsAndFixedRowHeight() {
        XCTAssertEqual(
            NativeFileTableConfiguration(layout: FileTableLayout(width: 499)).columns.map(\.kind),
            [.name, .size]
        )
        XCTAssertEqual(
            NativeFileTableConfiguration(layout: FileTableLayout(width: 500)).columns.map(\.kind),
            [.name, .size, .kind, .safety]
        )
        XCTAssertEqual(
            NativeFileTableConfiguration(layout: FileTableLayout(width: 700)).columns.map(\.kind),
            [.name, .size, .kind, .modified, .safety]
        )
        XCTAssertEqual(
            NativeFileTableConfiguration(layout: FileTableLayout(width: 980)).columns.map(\.kind),
            [.name, .size, .kind, .modified, .safety, .recommendation]
        )
        XCTAssertEqual(NativeFileTableConfiguration(layout: FileTableLayout(width: 499)).rowHeight, 42)
    }

    func testSelectionProjectionIgnoresIdentifiersOutsideTheVisibleRows() {
        let first = UUID()
        let second = UUID()
        let hidden = UUID()

        XCTAssertEqual(
            NativeFileTableSelection.rowIndexes(
                for: [first, second],
                selectedNodeIDs: [second, hidden]
            ),
            IndexSet(integer: 1)
        )
    }

    func testSelectionProjectionUsesTheCurrentRowIndexMap() {
        let first = UUID()
        let second = UUID()
        let hidden = UUID()

        XCTAssertEqual(
            NativeFileTableSelection.rowIndexes(
                for: [first: 1, second: 0],
                selectedNodeIDs: [second, hidden]
            ),
            IndexSet(integer: 0)
        )
    }

    func testOnlyTheFormerValueColumnsExposeHeaderSorting() {
        let columns = NativeFileTableConfiguration(layout: FileTableLayout(width: 980)).columns

        XCTAssertEqual(
            columns.filter(\.isSortable).map(\.kind),
            [.name, .size, .kind, .modified]
        )
    }

    func testRenderStateKeepsSelectionAndQueueMembershipIndependent() {
        let selected = UUID()
        let queued = UUID()

        let state = NativeFileTableRenderState(
            selectedNodeIDs: [selected],
            queuedNodeIDs: [queued]
        )

        XCTAssertEqual(state.selectedNodeIDs, [selected])
        XCTAssertEqual(state.queuedNodeIDs, [queued])
    }

    func testCompactRowsDoNotSpendTheirMinimumNameWidthOnDeepIndentation() {
        XCTAssertEqual(
            NativeFileTableNameCellLayout.indentation(depth: 8, showsQueuedText: false),
            0
        )
        XCTAssertEqual(
            NativeFileTableNameCellLayout.indentation(depth: 3, showsQueuedText: true),
            24
        )
    }

    func testSizeSortChangesTheVisibleRowOrderInBothDirections() {
        let small = FlattenedFileNode(
            node: FileNode(url: URL(fileURLWithPath: "/tmp/small"), isDirectory: false, logicalSize: 1, allocatedSize: 1),
            depth: 0
        )
        let large = FlattenedFileNode(
            node: FileNode(url: URL(fileURLWithPath: "/tmp/large"), isDirectory: false, logicalSize: 2, allocatedSize: 2),
            depth: 0
        )

        XCTAssertEqual(
            NativeFileTableSort(key: .size, order: .forward).sorted([large, small]).map(\.id),
            [small.id, large.id]
        )
        XCTAssertEqual(
            NativeFileTableSort(key: .size, order: .reverse).sorted([small, large]).map(\.id),
            [large.id, small.id]
        )
    }
}
