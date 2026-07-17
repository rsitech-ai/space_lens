import Foundation
import XCTest
@testable import SpaceLens

final class FileCleanupServiceTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceLensCleanupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
    }

    func testMoveToBinRejectsTargetReplacedBySymlinkAfterScan() async throws {
        let authorizedRoot = temporaryRoot.appendingPathComponent("authorized", isDirectory: true)
        let outsideRoot = temporaryRoot.appendingPathComponent("outside", isDirectory: true)
        let candidateURL = authorizedRoot.appendingPathComponent(".build", isDirectory: true)
        let outsideFile = outsideRoot.appendingPathComponent("valuable.txt")
        try FileManager.default.createDirectory(at: candidateURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideRoot, withIntermediateDirectories: true)
        try Data("keep me".utf8).write(to: outsideFile)

        let scannedNode = FileNode(
            url: candidateURL,
            isDirectory: true,
            logicalSize: 7,
            allocatedSize: 7
        )
        try FileManager.default.removeItem(at: candidateURL)
        try FileManager.default.createSymbolicLink(at: candidateURL, withDestinationURL: outsideRoot)

        do {
            try await FileCleanupService.moveToBin(node: scannedNode, authorizedRoot: authorizedRoot)
            XCTFail("Cleanup should reject an item whose filesystem identity changed after scanning")
        } catch {
            XCTAssertTrue(FileManager.default.fileExists(atPath: outsideFile.path))
        }
    }

    func testValidationRejectsDifferentDirectoryAtPreviouslyScannedPath() throws {
        let authorizedRoot = temporaryRoot.appendingPathComponent("authorized", isDirectory: true)
        let candidateURL = authorizedRoot.appendingPathComponent(".build", isDirectory: true)
        try FileManager.default.createDirectory(at: candidateURL, withIntermediateDirectories: true)
        let scannedNode = FileNode(
            url: candidateURL,
            isDirectory: true,
            logicalSize: 0,
            allocatedSize: 0
        )

        try FileManager.default.removeItem(at: candidateURL)
        try FileManager.default.createDirectory(at: candidateURL, withIntermediateDirectories: true)

        XCTAssertThrowsError(
            try FileCleanupService.validatedCleanupURL(for: scannedNode, authorizedRoot: authorizedRoot)
        ) { error in
            XCTAssertEqual(error as? CleanupValidationError, .targetChanged)
        }
    }

    func testValidationAcceptsUnchangedDescendantOfAuthorizedRoot() throws {
        let authorizedRoot = temporaryRoot.appendingPathComponent("authorized", isDirectory: true)
        let candidateURL = authorizedRoot.appendingPathComponent(".build", isDirectory: true)
        try FileManager.default.createDirectory(at: candidateURL, withIntermediateDirectories: true)
        let scannedNode = FileNode(
            url: candidateURL,
            isDirectory: true,
            logicalSize: 0,
            allocatedSize: 0
        )

        let validatedURL = try FileCleanupService.validatedCleanupURL(
            for: scannedNode,
            authorizedRoot: authorizedRoot
        )

        XCTAssertEqual(validatedURL, candidateURL.standardizedFileURL)
    }

    func testMoveToBinMovesUnchangedDescendantAndReportsResult() async throws {
        let authorizedRoot = temporaryRoot.appendingPathComponent("authorized", isDirectory: true)
        let candidateURL = authorizedRoot.appendingPathComponent("SpaceLens-(UUID().uuidString).tmp")
        try FileManager.default.createDirectory(at: authorizedRoot, withIntermediateDirectories: true)
        try Data("disposable audit fixture".utf8).write(to: candidateURL)
        let scannedNode = FileNode(
            url: candidateURL,
            isDirectory: false,
            logicalSize: 24,
            allocatedSize: 24
        )

        let resultingURL = try await FileCleanupService.moveToBin(
            node: scannedNode,
            authorizedRoot: authorizedRoot
        )
        defer {
            if let resultingURL {
                try? FileManager.default.removeItem(at: resultingURL)
            }
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: candidateURL.path))
        let trashURL = try XCTUnwrap(resultingURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: trashURL.path))
    }
}
