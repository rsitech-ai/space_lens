import Foundation
import XCTest
@testable import SpaceLens

final class FileRowPresentationTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

    func testLocationUsesHomeRelativeParentAndOmitsFilename() {
        let node = FileNode(
            url: URL(fileURLWithPath: "/Users/example/dev/App/.build/artifact.o"),
            isDirectory: false,
            logicalSize: 1,
            allocatedSize: 1
        )

        let presentation = FileRowPresentation(
            node: node,
            homeDirectory: home,
            isSelected: false,
            isQueued: false
        )

        XCTAssertEqual(presentation.name, "artifact.o")
        XCTAssertEqual(presentation.location, "~/dev/App/.build")
        XCTAssertFalse(presentation.location.contains("artifact.o"))
    }

    func testHomeRootParentDisplaysAsTilde() {
        let node = FileNode(
            url: home.appendingPathComponent("Downloads", isDirectory: true),
            isDirectory: true,
            logicalSize: 1,
            allocatedSize: 1
        )

        let presentation = FileRowPresentation(
            node: node,
            homeDirectory: home,
            isSelected: false,
            isQueued: false
        )

        XCTAssertEqual(presentation.location, "~")
    }

    func testLocationOutsideHomeRemainsAbsolute() {
        let node = FileNode(
            url: URL(fileURLWithPath: "/Volumes/Archive/cache/item.bin"),
            isDirectory: false,
            logicalSize: 1,
            allocatedSize: 1
        )

        let presentation = FileRowPresentation(
            node: node,
            homeDirectory: home,
            isSelected: false,
            isQueued: false
        )

        XCTAssertEqual(presentation.location, "/Volumes/Archive/cache")
    }

    func testSiblingHomePrefixIsNotAbbreviated() {
        let node = FileNode(
            url: URL(fileURLWithPath: "/Users/example-other/cache/item.bin"),
            isDirectory: false,
            logicalSize: 1,
            allocatedSize: 1
        )

        let presentation = FileRowPresentation(
            node: node,
            homeDirectory: home,
            isSelected: false,
            isQueued: false
        )

        XCTAssertEqual(presentation.location, "/Users/example-other/cache")
    }

    func testAccessibilityNamesSelectedAndQueuedStates() {
        let node = FileNode(
            url: URL(fileURLWithPath: "/Users/example/dev/App/.build"),
            isDirectory: true,
            logicalSize: 1,
            allocatedSize: 1
        )

        let presentation = FileRowPresentation(
            node: node,
            homeDirectory: home,
            isSelected: true,
            isQueued: true
        )

        XCTAssertEqual(
            presentation.accessibilityLabel,
            ".build, /Users/example/dev/App/.build, Selected, Queued for cleanup"
        )
    }
}
