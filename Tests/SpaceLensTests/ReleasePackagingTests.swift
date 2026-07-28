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
            version=1.0.2
            build=3
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

    func testNotarizationScriptDocumentsRequiredInputs() throws {
        let scriptURL = repositoryRoot.appendingPathComponent("script/notarize_direct_download.sh")
        XCTAssertTrue(
            FileManager.default.isExecutableFile(atPath: scriptURL.path),
            "The notarization finalizer must exist and be executable."
        )
        guard FileManager.default.isExecutableFile(atPath: scriptURL.path) else {
            return
        }

        let result = try run(scriptURL, arguments: ["--help"])

        XCTAssertEqual(result.status, 0, result.stderr)
        XCTAssertTrue(result.stdout.contains("SPACE_LENS_NOTARY_PROFILE"))
        XCTAssertTrue(result.stdout.contains("SPACE_LENS_RELEASE_INPUT_DIR"))
        XCTAssertTrue(result.stdout.contains("SPACE_LENS_NOTARIZED_OUTPUT_DIR"))
        XCTAssertTrue(result.stdout.contains("not modify the pre-notarization input"))
    }

    func testNotarizationScriptFinalizesAcceptedArtifactWithoutReusingInputZIP() throws {
        let scriptURL = repositoryRoot.appendingPathComponent("script/notarize_direct_download.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(script.contains("notarytool submit \"$INPUT_ZIP\""))
        XCTAssertTrue(script.contains("--keychain-profile \"$NOTARY_PROFILE\""))
        XCTAssertTrue(script.contains("--wait"))
        XCTAssertTrue(script.contains("test \"$NOTARY_STATUS\" = \"Accepted\""))
        XCTAssertTrue(script.contains("stapler staple \"$STAGED_APP\""))
        XCTAssertTrue(script.contains("stapler validate \"$STAGED_APP\""))
        XCTAssertTrue(script.contains("spctl -a -vv -t execute \"$STAGED_APP\""))

        let stapleRange = try XCTUnwrap(script.range(of: "stapler staple \"$STAGED_APP\""))
        let finalZipRange = try XCTUnwrap(
            script.range(of: "--keepParent \"$STAGED_APP\" \"$STAGED_ZIP\"")
        )
        XCTAssertLessThan(stapleRange.lowerBound, finalZipRange.lowerBound)
        XCTAssertTrue(script.contains("current_source_sha=\"$(git -C \"$ROOT_DIR\" rev-parse HEAD)\""))
        XCTAssertTrue(script.contains("current_source_tree=\"$(git -C \"$ROOT_DIR\" rev-parse HEAD^{tree})\""))
        XCTAssertTrue(script.contains("Refusing to finalize from a dirty source tree"))
        XCTAssertTrue(script.contains("validate_release_path_scope \"$OUTPUT_DIR\""))

        let finalSourceVerificationRange = try XCTUnwrap(
            script.range(of: "verify_source_revision\n", options: .backwards)
        )
        let finalChecksumRange = try XCTUnwrap(
            script.range(of: "shasum -a 256 -c SHA256SUMS.txt")
        )
        let publishRange = try XCTUnwrap(script.range(of: "mv \"$STAGING_DIR\" \"$OUTPUT_DIR\""))
        XCTAssertGreaterThan(finalSourceVerificationRange.lowerBound, finalChecksumRange.lowerBound)
        XCTAssertLessThan(finalSourceVerificationRange.lowerBound, publishRange.lowerBound)
    }

    func testCISelectsExactToolchainAndInstallsVerifiedXcodeGen() throws {
        let workflowURL = repositoryRoot.appendingPathComponent(".github/workflows/ci.yml")
        let workflow = try String(contentsOf: workflowURL, encoding: .utf8)

        XCTAssertTrue(
            workflow.contains("/Applications/Xcode_26.6.app/Contents/Developer")
        )
        XCTAssertTrue(workflow.contains("test \"$XCODE_VERSION\" = \"26.6\""))
        XCTAssertTrue(
            workflow.contains("XCODEGEN_VERSION: 2.45.4")
        )
        XCTAssertTrue(
            workflow.contains("090ec29491aad50aec10631bf6e62253fed733c50f3aab0f5ffc86bc170bdbef")
        )
        XCTAssertTrue(workflow.contains("shasum -a 256 -c -"))
        XCTAssertFalse(workflow.contains("brew install xcodegen"))
    }

    func testDirectDownloadScriptPinsAndRevalidatesSourceRevision() throws {
        let scriptURL = repositoryRoot.appendingPathComponent("script/build_direct_download.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        let buildRange = try XCTUnwrap(script.range(of: "xcodebuild \\"))
        let pinnedCommitRange = try XCTUnwrap(
            script.range(of: "SOURCE_SHA=\"$(git -C \"$ROOT_DIR\" rev-parse HEAD)\"")
        )
        let pinnedTreeRange = try XCTUnwrap(
            script.range(of: "SOURCE_TREE=\"$(git -C \"$ROOT_DIR\" rev-parse HEAD^{tree})\"")
        )

        XCTAssertLessThan(pinnedCommitRange.lowerBound, buildRange.lowerBound)
        XCTAssertLessThan(pinnedTreeRange.lowerBound, buildRange.lowerBound)
        XCTAssertTrue(
            script.contains("current_source_sha=\"$(git -C \"$ROOT_DIR\" rev-parse HEAD)\"")
        )
        XCTAssertTrue(
            script.contains("current_source_tree=\"$(git -C \"$ROOT_DIR\" rev-parse HEAD^{tree})\"")
        )
        XCTAssertTrue(script.contains("-n \"$current_source_status\""))
        XCTAssertTrue(
            script.contains("git -C \"$ROOT_DIR\" check-ignore -q --no-index -- \"$relative_release_path\"")
        )
        XCTAssertTrue(
            script.contains("git -C \"$ROOT_DIR\" check-ignore -q --no-index -- \"${relative_release_path}/\"")
        )
        XCTAssertTrue(
            script.contains("Release paths inside the source tree must be ignored by Git")
        )
        XCTAssertTrue(script.contains("Refusing unsafe resolved release path"))
        XCTAssertTrue(script.contains("Release output and DerivedData paths must not overlap"))

        let finalVerificationRange = try XCTUnwrap(
            script.range(of: "verify_source_revision\n", options: .backwards)
        )
        let checksumRange = try XCTUnwrap(script.range(of: "shasum -a 256"))
        XCTAssertGreaterThan(finalVerificationRange.lowerBound, checksumRange.lowerBound)
    }

    private func run(_ executableURL: URL, arguments: [String]) throws -> (
        status: Int32,
        stdout: String,
        stderr: String
    ) {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceLensReleasePackagingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let stdoutURL = temporaryDirectory.appendingPathComponent("stdout.txt")
        let stderrURL = temporaryDirectory.appendingPathComponent("stderr.txt")
        XCTAssertTrue(FileManager.default.createFile(atPath: stdoutURL.path, contents: nil))
        XCTAssertTrue(FileManager.default.createFile(atPath: stderrURL.path, contents: nil))

        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdout.close()
            try? stderr.close()
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = repositoryRoot
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()
        try stdout.synchronize()
        try stderr.synchronize()

        return (
            process.terminationStatus,
            String(decoding: try Data(contentsOf: stdoutURL), as: UTF8.self),
            String(decoding: try Data(contentsOf: stderrURL), as: UTF8.self)
        )
    }
}
