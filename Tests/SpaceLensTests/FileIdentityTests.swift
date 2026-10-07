import Darwin
import Foundation
import XCTest
@testable import SpaceLens

final class FileIdentityTests: XCTestCase {
    func testCapturesDeviceIdentifierBitsWithoutUnsignedConversionTrap() throws {
        var metadata = stat()
        XCTAssertEqual(lstat("/dev/null", &metadata), 0)
        let identity = try XCTUnwrap(FileIdentity.capture(at: URL(fileURLWithPath: "/dev/null")))
        XCTAssertEqual(identity.deviceID, UInt64(UInt32(bitPattern: metadata.st_dev)))
        XCTAssertEqual(identity.fileID, UInt64(metadata.st_ino))
        XCTAssertEqual(identity.fileType, UInt32(S_IFCHR))
    }
}
