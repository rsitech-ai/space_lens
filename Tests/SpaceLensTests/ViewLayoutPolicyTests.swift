import XCTest
@testable import SpaceLens

final class ViewLayoutPolicyTests: XCTestCase {
    func testTableControlsStackAtTypicalSplitViewWidths() {
        XCTAssertTrue(FileTableLayout(width: 840).usesStackedControls)
        XCTAssertTrue(FileTableLayout(width: 1_100).usesStackedControls)
    }

    func testTableControlsUseSingleRowOnlyWhenThereIsEnoughWidth() {
        XCTAssertFalse(FileTableLayout(width: 1_200).usesStackedControls)
    }

    func testQueuedTextIsHiddenOnlyInCompactTable() {
        XCTAssertFalse(FileTableLayout(width: 619).showsQueuedText)
        XCTAssertTrue(FileTableLayout(width: 620).showsQueuedText)
        XCTAssertTrue(FileTableLayout(width: 1_200).showsQueuedText)
    }

    func testFileRowsReserveHeightForTheirSecondaryLocation() {
        XCTAssertEqual(FileTableLayout(width: 619).rowHeight, 42)
        XCTAssertEqual(FileTableLayout(width: 1_200).rowHeight, 42)
    }

    func testTableRenderIdentityChangesWhenVisibleRowStateChanges() {
        let nodeID = UUID()
        let base = FileTableRenderIdentity(
            visibleNodeIDs: [nodeID],
            selectedNodeIDs: [],
            queuedNodeIDs: []
        )

        XCTAssertNotEqual(
            base,
            FileTableRenderIdentity(
                visibleNodeIDs: [nodeID],
                selectedNodeIDs: [nodeID],
                queuedNodeIDs: []
            )
        )
        XCTAssertNotEqual(
            base,
            FileTableRenderIdentity(
                visibleNodeIDs: [nodeID],
                selectedNodeIDs: [],
                queuedNodeIDs: [nodeID]
            )
        )
    }

    func testScanMotionStopsWhenReduceMotionIsEnabled() {
        XCTAssertFalse(ScanMotionPolicy.allowsContinuousMotion(reduceMotion: true))
        XCTAssertTrue(ScanMotionPolicy.allowsContinuousMotion(reduceMotion: false))
    }
}
