import AppKit
import XCTest
@testable import SpaceLens

@MainActor
final class NativeTableHostConfigurationTests: XCTestCase {
    func testTwoLineConfigurationAppliesCustomFixedHeightOnlyOnce() {
        let tableView = NSTableView()
        tableView.rowSizeStyle = .large
        tableView.rowHeight = 17
        tableView.usesAutomaticRowHeights = true

        let configuration = NativeTableHostConfiguration(rowHeight: 42)

        XCTAssertTrue(configuration.apply(to: tableView))
        XCTAssertEqual(tableView.rowSizeStyle, .custom)
        XCTAssertEqual(tableView.rowHeight, 42)
        XCTAssertFalse(tableView.usesAutomaticRowHeights)
        XCTAssertFalse(configuration.apply(to: tableView))
    }

    func testCellAccessibilityBridgeSetsTheNativeCellLabel() {
        let cell = NSTableCellView()
        let probe = NativeTableCellAccessibilityProbeView(label: "artifact.pack, /tmp/artifact.pack, Queued for cleanup")
        cell.addSubview(probe)

        probe.configureCellIfNeeded()

        XCTAssertEqual(
            cell.accessibilityLabel(),
            "artifact.pack, /tmp/artifact.pack, Queued for cleanup"
        )
    }
}
