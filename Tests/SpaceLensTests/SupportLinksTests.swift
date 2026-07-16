import XCTest
@testable import SpaceLens

final class SupportLinksTests: XCTestCase {
    func testStoreBuildDoesNotExposeAnExternalTipURL() {
        XCTAssertNil(SupportLinks.externalTipURL)
    }
}
