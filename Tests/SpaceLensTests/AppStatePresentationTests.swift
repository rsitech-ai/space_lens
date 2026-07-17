import XCTest
@testable import SpaceLens

final class AppStatePresentationTests: XCTestCase {
    func testLocalAnalysisCopyNamesTheRuleBasedImplementation() {
        XCTAssertEqual(ProductCopy.localAnalysisTitle, "Local rule-based analysis")
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
