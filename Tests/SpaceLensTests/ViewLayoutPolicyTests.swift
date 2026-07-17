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

    func testScanMotionStopsWhenReduceMotionIsEnabled() {
        XCTAssertFalse(ScanMotionPolicy.allowsContinuousMotion(reduceMotion: true))
        XCTAssertTrue(ScanMotionPolicy.allowsContinuousMotion(reduceMotion: false))
    }
}
