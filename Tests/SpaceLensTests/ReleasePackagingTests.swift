import Foundation
import XCTest

final class ReleasePackagingTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testDirectDownloadScriptExposesSourceOfTruthConfiguration() throws {
        let scriptURL = repositoryRoot.appendingPathComponent("script/build_direct_download.sh")
        XCTAssertTrue(
            FileManager.default.isExecutableFile(atPath: scriptURL.path),
            "The direct-download packaging script must exist and be executable."
        )
        guard FileManager.default.isExecutableFile(atPath: scriptURL.path) else {
            return
        }

        let result = try run(scriptURL, arguments: ["--print-config"])

        XCTAssertEqual(result.status, 0, result.stderr)
        XCTAssertEqual(
            result.stdout,
            """
            bundle_id=com.rsitech.spacelens
            version=1.0
            build=1
            minimum_macos=14.0

            """
        )
    }

    func testDirectDownloadScriptDocumentsRequiredSigningInput() throws {
        let scriptURL = repositoryRoot.appendingPathComponent("script/build_direct_download.sh")
        XCTAssertTrue(
            FileManager.default.isExecutableFile(atPath: scriptURL.path),
            "The direct-download packaging script must exist and be executable."
        )
        guard FileManager.default.isExecutableFile(atPath: scriptURL.path) else {
            return
        }

        let result = try run(scriptURL, arguments: ["--help"])

        XCTAssertEqual(result.status, 0, result.stderr)
        XCTAssertTrue(result.stdout.contains("SPACE_LENS_DEVELOPER_ID"))
        XCTAssertTrue(result.stdout.contains("Developer ID"))
    }

    private func run(_ executableURL: URL, arguments: [String]) throws -> (
        status: Int32,
        stdout: String,
        stderr: String
    ) {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = repositoryRoot
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        return (
            process.terminationStatus,
            String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }
}
