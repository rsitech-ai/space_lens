import Foundation
import XCTest
@testable import SpaceLens

final class SmartCleanupScannerTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceLensSmartScanTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
    }

    func testSmartScanFindsCacheRootsWithoutReturningEveryLeaf() async throws {
        let buildFolder = temporaryRoot.appendingPathComponent("Project/.build", isDirectory: true)
        let derivedOutput = temporaryRoot.appendingPathComponent("Project/dist", isDirectory: true)
        let valuableData = temporaryRoot.appendingPathComponent("Project/data/raw", isDirectory: true)
        try FileManager.default.createDirectory(at: buildFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: derivedOutput, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: valuableData, withIntermediateDirectories: true)

        try writeSparseFile(buildFolder.appendingPathComponent("artifact.o"), size: 12_000_000)
        try writeSparseFile(derivedOutput.appendingPathComponent("bundle.zip"), size: 8_000_000)
        try writeSparseFile(valuableData.appendingPathComponent("dataset.bin"), size: 32_000_000)

        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: temporaryRoot)

        XCTAssertEqual(result.root.children.map(\.name), [".build", "dist"])
        XCTAssertEqual(result.root.children.flatMap(\.children).count, 0)
        XCTAssertGreaterThanOrEqual(result.snapshot.totalLogicalSize, 20_000_000)
        XCTAssertFalse(result.root.children.contains { $0.path.contains("/data/raw") })
    }

    func testSmartScanIncludesKnownHomeRelativeCacheLocations() async throws {
        let gradleCache = temporaryRoot.appendingPathComponent(".gradle/caches/modules-2", isDirectory: true)
        try FileManager.default.createDirectory(at: gradleCache, withIntermediateDirectories: true)
        try writeSparseFile(gradleCache.appendingPathComponent("module.bin"), size: 5_000_000)

        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: temporaryRoot)

        XCTAssertTrue(result.root.children.contains { $0.path.hasSuffix(".gradle/caches") })
        XCTAssertGreaterThanOrEqual(result.snapshot.totalLogicalSize, 5_000_000)
    }

    func testSmartScanFindsNodeModulesCacheWithoutScanningAllNodeModules() async throws {
        let packageCache = temporaryRoot.appendingPathComponent("Web/node_modules/.cache", isDirectory: true)
        let dependency = temporaryRoot.appendingPathComponent("Web/node_modules/react", isDirectory: true)
        try FileManager.default.createDirectory(at: packageCache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dependency, withIntermediateDirectories: true)
        try writeSparseFile(packageCache.appendingPathComponent("bundle-cache.bin"), size: 4_000_000)
        try writeSparseFile(dependency.appendingPathComponent("index.js"), size: 9_000_000)

        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: temporaryRoot)

        XCTAssertTrue(result.root.children.contains { $0.path.hasSuffix("node_modules/.cache") })
        XCTAssertFalse(result.root.children.contains { $0.path.hasSuffix("node_modules/react") })
    }

    func testSmartScanDoesNotTreatSiblingHomePrefixAsInsideHome() async throws {
        let siblingRoot = temporaryRoot
            .deletingLastPathComponent()
            .appendingPathComponent("\(temporaryRoot.lastPathComponent)-sibling", isDirectory: true)
        try FileManager.default.createDirectory(at: siblingRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: siblingRoot)
        }

        let buildFolder = siblingRoot.appendingPathComponent("Project/.build", isDirectory: true)
        try FileManager.default.createDirectory(at: buildFolder, withIntermediateDirectories: true)
        try writeSparseFile(buildFolder.appendingPathComponent("artifact.o"), size: 6_000_000)

        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: siblingRoot)

        XCTAssertTrue(result.root.children.isEmpty)
    }

    private func writeSparseFile(_ url: URL, size: UInt64) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: size)
        try handle.close()
    }
}
