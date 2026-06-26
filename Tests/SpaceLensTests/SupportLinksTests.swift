import XCTest
@testable import SpaceLens

final class SupportLinksTests: XCTestCase {
    func testBuyMeACoffeeURL() {
        XCTAssertEqual(SupportLinks.buyMeACoffee.absoluteString, "https://buymeacoffee.com/s1korrrr")
    }
}
