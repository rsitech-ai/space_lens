import XCTest
@testable import SpaceLens

final class ByteFormatTests: XCTestCase {
    func testFormatsBytes() {
        let value = ByteFormat.string(1_048_576)
        XCTAssertTrue(value.contains("MB") || value.contains("megabyte"))
    }
}
