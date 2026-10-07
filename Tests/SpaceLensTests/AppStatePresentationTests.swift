import XCTest
@testable import SpaceLens

final class AppStatePresentationTests: XCTestCase {
    func testLocalAnalysisCopyNamesTheRuleBasedImplementation() {
        XCTAssertEqual(ProductCopy.localAnalysisTitle, "Local rule-based analysis")
    }

    @MainActor
    func testSmartScanEmptyStateExplainsCollapsedCandidates() {
        let appState = AppState(requiresSecurityScopedAccess: false)
        appState.scanMode = .smart
        appState.isScanning = true

        XCTAssertEqual(appState.emptyResultsPresentation.title, "Finding Cleanup Candidates")
    }

    @MainActor
    func testScanErrorsIncludesRootWhenUnreadableDetailsAreOmitted() {
        let appState = AppState(requiresSecurityScopedAccess: false)
        appState.rootNode = FileNode(
            url: URL(fileURLWithPath: "/tmp/SpaceLens-errors"), isDirectory: true,
            logicalSize: 100, allocatedSize: 100,
            children: [FileNode(url: URL(fileURLWithPath: "/tmp/SpaceLens-errors/readable"),
                                isDirectory: false, logicalSize: 100, allocatedSize: 100)],
            scanError: "Some descendants could not be read."
        )
        appState.sidebarSelection = .errors
        XCTAssertEqual(appState.visibleNodes.map(\.node.path), ["/tmp/SpaceLens-errors"])
        XCTAssertFalse(appState.classification(for: appState.visibleNodes[0].node).level.isQueueable)
    }

    @MainActor
    func testScanErrorsCategoryHasAContextualEmptyState() {
        let appState = AppState(requiresSecurityScopedAccess: false)
        appState.sidebarSelection = .errors

        XCTAssertEqual(appState.emptyResultsPresentation.title, "No Scan Errors")
        XCTAssertEqual(
            appState.emptyResultsPresentation.description,
            "SpaceLens read every scanned location successfully."
        )
    }

    @MainActor
    func testCleanupQueueHasAContextualEmptyState() {
        let appState = AppState(requiresSecurityScopedAccess: false)
        appState.sidebarSelection = .queue

        XCTAssertEqual(appState.emptyResultsPresentation.title, "Cleanup Queue Is Empty")
    }

    @MainActor
    func testSearchTakesPrecedenceOverCategoryEmptyState() {
        let appState = AppState(requiresSecurityScopedAccess: false)
        appState.sidebarSelection = .errors
        appState.searchText = "not-present"

        XCTAssertEqual(appState.emptyResultsPresentation.title, "No Matching Items")
        XCTAssertEqual(appState.emptyResultsPresentation.description, "Try another search or filter.")
    }
}
