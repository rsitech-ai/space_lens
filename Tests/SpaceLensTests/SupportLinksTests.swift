import XCTest
@testable import SpaceLens

final class SupportLinksTests: XCTestCase {
    func testSupportURLMatchesThePublishedSpaceLensHelpPage() throws {
        XCTAssertEqual(
            try XCTUnwrap(SupportLinks.supportURL).absoluteString,
            "https://www.rsitech.ai/spacelens/support"
        )
    }

    func testStoreBuildDoesNotExposeAnExternalTipURL() {
        XCTAssertNil(SupportLinks.externalTipURL)
    }
}
