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

    func testSmartScanRejectsVirtualPathNamespacesWithoutDiscovery() async {
        for path in ["/.nofollow", "/.nofollow/Users", "/.resolve", "/dev"] {
            let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: URL(fileURLWithPath: path))
            XCTAssertEqual(result.snapshot.nodeCount, 1)
            XCTAssertEqual(result.snapshot.errorCount, 1)
            XCTAssertTrue(result.root.children.isEmpty)
            XCTAssertFalse(RuleEngine().classify(result.root).level.isQueueable)
        }
    }

    func testSmartScanCollapsesDerivedDataTargetAndNodeModules() async throws {
        let derivedData = temporaryRoot.appendingPathComponent(
            "Library/Developer/XcodeBuildMCP/workspaces/heat-cycle/DerivedData",
            isDirectory: true
        )
        let nodeModules = temporaryRoot.appendingPathComponent("dev/web/node_modules/react", isDirectory: true)
        let cargoTarget = temporaryRoot.appendingPathComponent("dev/svc/target/debug", isDirectory: true)
        try FileManager.default.createDirectory(at: derivedData, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cargoTarget, withIntermediateDirectories: true)
        try Data("[package]\nname = \"svc\"\nversion = \"0.1.0\"\nedition = \"2021\"\n".utf8).write(
            to: cargoTarget.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Cargo.toml")
        )

        let leafCount = 2_500
        for index in 0..<leafCount {
            FileManager.default.createFile(
                atPath: derivedData.appendingPathComponent("object-\(index).o").path,
                contents: Data([1])
            )
        }
        FileManager.default.createFile(atPath: nodeModules.appendingPathComponent("index.js").path, contents: Data([1]))
        FileManager.default.createFile(atPath: cargoTarget.appendingPathComponent("lib.rlib").path, contents: Data([1]))

        let liveCounts = CountRecorder()
        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(
            root: temporaryRoot,
            onCandidates: { liveCounts.values.append($0.count) }
        )

        func retainedCount(_ node: FileNode) -> Int {
            1 + node.children.reduce(0) { $0 + retainedCount($1) }
        }

        XCTAssertFalse(liveCounts.values.isEmpty)
        XCTAssertEqual(retainedCount(result.root), 1 + result.root.children.count)
        XCTAssertLessThan(result.createdNodeCount, 30)
        XCTAssertGreaterThanOrEqual(result.snapshot.fileCount, leafCount)
        XCTAssertTrue(result.root.children.contains { $0.path.hasSuffix("/DerivedData") && $0.children.isEmpty })
        XCTAssertTrue(result.root.children.contains { $0.path.hasSuffix("/node_modules") && $0.children.isEmpty })
        XCTAssertTrue(result.root.children.contains { $0.path.hasSuffix("/target") && $0.children.isEmpty })
        XCTAssertFalse(result.root.children.contains { $0.path.hasSuffix(".o") })
    }

    func testSmartScanCancelStopsBeforeFinishingPendingRoots() async throws {
        let derivedData = temporaryRoot.appendingPathComponent(
            "Library/Developer/Xcode/DerivedData",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: derivedData, withIntermediateDirectories: true)
        for index in 0..<4_000 {
            FileManager.default.createFile(
                atPath: derivedData.appendingPathComponent("object-\(index).o").path,
                contents: Data([1])
            )
        }

        let started = Date()
        let home = temporaryRoot!
        let task = Task {
            await SmartCleanupScanner(homeDirectory: home).scan(root: home)
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()
        let result = await task.value

        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
        XCTAssertLessThan(result.createdNodeCount, 30)
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

        XCTAssertEqual(result.root.children.map(\.displayName), ["Build Artifacts (.build)"])
        XCTAssertEqual(result.root.children.flatMap(\.children).count, 0)
        XCTAssertGreaterThanOrEqual(result.snapshot.totalLogicalSize, 12_000_000)
        XCTAssertLessThan(result.snapshot.totalLogicalSize, 20_000_000)
        XCTAssertFalse(result.root.children.contains { $0.path.contains("/data/raw") })
    }

    func testSmartScanIncludesKnownHomeRelativeCacheLocations() async throws {
        let gradleCache = temporaryRoot.appendingPathComponent(".gradle/caches/modules-2", isDirectory: true)
        try FileManager.default.createDirectory(at: gradleCache, withIntermediateDirectories: true)
        try writeSparseFile(gradleCache.appendingPathComponent("module.bin"), size: 5_000_000)

        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: temporaryRoot)

        XCTAssertTrue(result.root.children.contains { $0.displayName == "Gradle Caches" })
        XCTAssertGreaterThanOrEqual(result.snapshot.totalLogicalSize, 5_000_000)
    }

    func testSmartScanUsesGenericCandidateNamesWithoutDeveloperSpecificLocations() async throws {
        let derivedData = temporaryRoot.appendingPathComponent("Library/Developer/Xcode/DerivedData/App", isDirectory: true)
        let codexSessions = temporaryRoot.appendingPathComponent(".codex/sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: derivedData, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexSessions, withIntermediateDirectories: true)
        try writeSparseFile(derivedData.appendingPathComponent("build.db"), size: 4_000_000)
        try writeSparseFile(codexSessions.appendingPathComponent("session.jsonl"), size: 2_000_000)

        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: temporaryRoot)
        let displayNames = Set(result.root.children.map(\.displayName))

        XCTAssertTrue(displayNames.contains("Xcode DerivedData"))
        XCTAssertTrue(displayNames.contains("Codex Sessions"))
        let sessions = try XCTUnwrap(result.root.children.first { $0.displayName == "Codex Sessions" })
        XCTAssertFalse(RuleEngine(homeDirectory: temporaryRoot).classify(sessions).level.isQueueable)
    }

    func testSmartScanFindsWholeNodeModulesNotOnlyCache() async throws {
        let packageCache = temporaryRoot.appendingPathComponent("Web/node_modules/.cache", isDirectory: true)
        let dependency = temporaryRoot.appendingPathComponent("Web/node_modules/react", isDirectory: true)
        try FileManager.default.createDirectory(at: packageCache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dependency, withIntermediateDirectories: true)
        try writeSparseFile(packageCache.appendingPathComponent("bundle-cache.bin"), size: 4_000_000)
        try writeSparseFile(dependency.appendingPathComponent("index.js"), size: 9_000_000)

        try Data("{}".utf8).write(to: temporaryRoot.appendingPathComponent("Web/package.json"))
        try Data("{}".utf8).write(to: temporaryRoot.appendingPathComponent("Web/package-lock.json"))
        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: temporaryRoot)
        let node = try XCTUnwrap(result.root.children.first { $0.path.hasSuffix("/node_modules") })
        let classification = RuleEngine(homeDirectory: temporaryRoot).classify(node)

        XCTAssertEqual(node.displayName, "Node Modules")
        XCTAssertGreaterThanOrEqual(node.effectiveSize, 13_000_000)
        XCTAssertFalse(result.root.children.contains { $0.path.hasSuffix("node_modules/react") })
        XCTAssertFalse(result.root.children.contains { $0.path.hasSuffix("node_modules/.cache") })
        XCTAssertEqual(classification.kind, .packageCache)
        XCTAssertEqual(classification.level, .rebuildableCache)
        XCTAssertTrue(classification.level.isQueueable)
        XCTAssertNotEqual(classification.kind, .userHistory)
        XCTAssertNotEqual(classification.kind, .unknownLarge)
    }

    func testSmartScanDiscoversBuildsInAnySelectedFolder() async throws {
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

        XCTAssertTrue(result.root.children.contains { $0.path == buildFolder.path })
    }

    func testSmartScanDoesNotTreatNestedLibraryCachesAsUserCache() async throws {
        let valuableDirectory = temporaryRoot
            .appendingPathComponent("Documents/Project/Library/Caches/Photos", isDirectory: true)
        try FileManager.default.createDirectory(at: valuableDirectory, withIntermediateDirectories: true)
        try writeSparseFile(valuableDirectory.appendingPathComponent("originals.bin"), size: 6_000_000)

        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: temporaryRoot)

        XCTAssertFalse(result.root.children.contains { $0.path == valuableDirectory.path })
    }

    func testSmartScanCountsDiscoveryPermissionErrors() async throws {
        let blockedDirectory = temporaryRoot.appendingPathComponent("Blocked", isDirectory: true)
        try FileManager.default.createDirectory(at: blockedDirectory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: blockedDirectory.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: blockedDirectory.path)
        }

        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: temporaryRoot)

        XCTAssertGreaterThan(result.snapshot.errorCount, 0)
        XCTAssertTrue(result.root.children.contains { $0.scanError != nil })
    }

    func testSmartScanFindsWorktreeCargoTargetAndClassifiesItRebuildable() async throws {
        let worktreeTarget = temporaryRoot.appendingPathComponent(
            "dev/apps/alpha-desk/.worktrees/oss-production/target",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: worktreeTarget.appendingPathComponent("debug", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data("[package]\nname = \"alpha-desk\"\nversion = \"0.1.0\"\nedition = \"2021\"\n".utf8).write(
            to: worktreeTarget.deletingLastPathComponent().appendingPathComponent("Cargo.toml")
        )
        try writeSparseFile(worktreeTarget.appendingPathComponent("debug/lib.rlib"), size: 64_000_000)

        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: temporaryRoot)
        let node = try XCTUnwrap(result.root.children.first { $0.path.hasSuffix("/.worktrees/oss-production/target") })
        let classification = RuleEngine(homeDirectory: temporaryRoot).classify(node)

        XCTAssertGreaterThanOrEqual(node.effectiveSize, 64_000_000)
        XCTAssertEqual(classification.level, .rebuildableCache)
        XCTAssertEqual(classification.kind, .rebuildableCache)
        XCTAssertTrue(classification.level.isQueueable)
    }

    func testHomeScanFindsDeveloperTreeBuildRootsWithoutWalkingLibrary() async throws {
        let libraryNoise = temporaryRoot.appendingPathComponent("Library/Caches/com.apple.huge", isDirectory: true)
        let worktreeBuild = temporaryRoot.appendingPathComponent(
            "dev/apps/heat-cycle/.worktrees/precision/.build",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: libraryNoise, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: worktreeBuild, withIntermediateDirectories: true)
        try writeSparseFile(libraryNoise.appendingPathComponent("blob.bin"), size: 8_000_000)
        try writeSparseFile(worktreeBuild.appendingPathComponent("artifact.o"), size: 9_000_000)

        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: temporaryRoot)
        let paths = result.root.children.map(\.path)

        XCTAssertTrue(paths.contains(where: { $0.hasSuffix("/.worktrees/precision/.build") }))
        XCTAssertTrue(paths.contains(where: { $0.hasSuffix("/Library/Caches/com.apple.huge") }))
    }

    func testHomeScanSchedulesDocumentsLibraryAndDeveloperTrees() throws {
        for name in ["dev", "Documents", "Library", "Desktop", "Downloads"] {
            try FileManager.default.createDirectory(
                at: temporaryRoot.appendingPathComponent(name, isDirectory: true),
                withIntermediateDirectories: true
            )
        }

        let roots = SmartCleanupScanner(homeDirectory: temporaryRoot)
            .scheduledDiscoveryRoots(containedIn: temporaryRoot)
        let names = Set(roots.map { $0.lastPathComponent.lowercased() })

        XCTAssertTrue(names.contains("dev"))
        XCTAssertTrue(names.contains("documents"))
        XCTAssertTrue(names.contains("library"))
        XCTAssertTrue(names.contains("desktop"))
        XCTAssertTrue(names.contains("downloads"))
        XCTAssertFalse(SmartScanCatalog.userContentRootNames.contains("dev"))
    }

    func testHomeScanInventoriesDocumentsLargeFileAsUserData() async throws {
        let archive = temporaryRoot.appendingPathComponent("Documents/Archive", isDirectory: true)
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        try writeSparseFile(archive.appendingPathComponent("export.bin"), size: 20_000_000)

        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: temporaryRoot)
        let node = try XCTUnwrap(result.root.children.first { $0.path.hasSuffix("/Documents/Archive/export.bin") })
        let classification = RuleEngine(homeDirectory: temporaryRoot).classify(node)

        XCTAssertGreaterThanOrEqual(node.effectiveSize, 20_000_000)
        XCTAssertEqual(classification.kind, .unknownLarge)
        XCTAssertFalse(classification.level.isQueueable)
        XCTAssertNotEqual(classification.level, .rebuildableCache)
        XCTAssertNotEqual(classification.kind, .packageCache)
    }

    func testSmartScanEmitsPerDeviceSimulatorRowsFromInventory() async throws {
        let booted = temporaryRoot.appendingPathComponent(
            "Library/Developer/CoreSimulator/Devices/AAA/data",
            isDirectory: true
        )
        let unavailable = temporaryRoot.appendingPathComponent(
            "Library/Developer/CoreSimulator/Devices/BBB/data",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: booted, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unavailable, withIntermediateDirectories: true)
        try writeSparseFile(booted.appendingPathComponent("container.dat"), size: 2_000_000)
        try writeSparseFile(unavailable.appendingPathComponent("container.dat"), size: 3_000_000)

        let inventory = SimulatorInventory(devices: [
            SimulatorDevice(
                udid: "AAA",
                name: "iPhone 15",
                runtime: "iOS-17",
                state: "Booted",
                isAvailable: true,
                dataPath: booted.path
            ),
            SimulatorDevice(
                udid: "BBB",
                name: "iPhone 8",
                runtime: "iOS-16",
                state: "Shutdown",
                isAvailable: false,
                dataPath: unavailable.path
            )
        ])
        let result = await SmartCleanupScanner(
            homeDirectory: temporaryRoot,
            simulatorInventory: inventory
        ).scan(root: temporaryRoot)
        let pathUse = PathUseSnapshot(
            runningToolLabels: [],
            xcodeFamilyActive: false,
            dockerActive: false,
            cursorActive: false,
            cargoActive: false,
            simulatorInventory: inventory
        )
        let rules = RuleEngine(homeDirectory: temporaryRoot)
        let bootedNode = try XCTUnwrap(result.root.children.first { $0.path == booted.path })
        let unavailableNode = try XCTUnwrap(result.root.children.first { $0.path == unavailable.path })

        XCTAssertEqual(bootedNode.displayName, "Simulator: iPhone 15 (Booted)")
        XCTAssertEqual(unavailableNode.displayName, "Simulator: iPhone 8 (Shutdown)")
        XCTAssertEqual(rules.classify(bootedNode, pathUse: pathUse).level, .activeOrInUse)
        XCTAssertEqual(rules.classify(unavailableNode, pathUse: pathUse).kind, .simulator)
        XCTAssertFalse(rules.classify(unavailableNode, pathUse: pathUse).level.isQueueable)
        XCTAssertTrue(rules.classify(unavailableNode, pathUse: pathUse).recommendedAction.lowercased().contains("unavailable"))
    }

    func testHomeScanStaysInsideAuthorizedHome() {
        let realHome = FileManager.default.homeDirectoryForCurrentUser
        let extraOnHome = SmartScanCatalog.extraSystemRoots(scanRoot: realHome, homeDirectory: realHome)
        let extraOnFixture = SmartScanCatalog.extraSystemRoots(scanRoot: temporaryRoot, homeDirectory: temporaryRoot)

        XCTAssertTrue(extraOnHome.isEmpty)
        XCTAssertTrue(extraOnFixture.isEmpty)
    }

    func testSmartScanFindsCargoTargetOnlyWhenManifestExists() async throws {
        let cargoTarget = temporaryRoot.appendingPathComponent("dev/service/target", isDirectory: true)
        let strayTarget = temporaryRoot.appendingPathComponent("Documents/target", isDirectory: true)
        try FileManager.default.createDirectory(at: cargoTarget, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: strayTarget, withIntermediateDirectories: true)
        try Data("[package]\nname = \"service\"\nversion = \"0.1.0\"\nedition = \"2021\"\n".utf8).write(
            to: cargoTarget.deletingLastPathComponent().appendingPathComponent("Cargo.toml")
        )
        try writeSparseFile(cargoTarget.appendingPathComponent("lib.rlib"), size: 3_000_000)
        try writeSparseFile(strayTarget.appendingPathComponent("dataset.bin"), size: 4_000_000)

        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: temporaryRoot)
        let paths = result.root.children.map(\.path)

        XCTAssertTrue(paths.contains(where: { $0.hasSuffix("/dev/service/target") }))
        XCTAssertFalse(paths.contains(where: { $0.hasSuffix("/Documents/target") }))
    }

    func testSmartScanFindsPythonCachesAndLeavesVenvAsReview() async throws {
        let pycache = temporaryRoot.appendingPathComponent("dev/tools/__pycache__", isDirectory: true)
        let venv = temporaryRoot.appendingPathComponent("dev/tools/.venv", isDirectory: true)
        try FileManager.default.createDirectory(at: pycache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: venv, withIntermediateDirectories: true)
        try writeSparseFile(pycache.appendingPathComponent("mod.pyc"), size: 1_000_000)
        try writeSparseFile(venv.appendingPathComponent("pyvenv.cfg"), size: 2_000_000)

        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: temporaryRoot)
        let rules = RuleEngine(homeDirectory: temporaryRoot)
        let pycacheNode = try XCTUnwrap(result.root.children.first { $0.path.hasSuffix("/__pycache__") })
        let venvNode = try XCTUnwrap(result.root.children.first { $0.path.hasSuffix("/.venv") })

        XCTAssertEqual(rules.classify(pycacheNode).level, .rebuildableCache)
        XCTAssertEqual(rules.classify(venvNode).level, .unknownReview)
        XCTAssertFalse(rules.classify(venvNode).level.isQueueable)
    }

    func testSmartScanKeepsResearchOutputAndCursorUserConditional() async throws {
        let research = temporaryRoot.appendingPathComponent("dev/quants-lab/output", isDirectory: true)
        let cursorUser = temporaryRoot.appendingPathComponent(
            "Library/Application Support/Cursor/User/globalStorage",
            isDirectory: true
        )
        let cursorCache = temporaryRoot.appendingPathComponent(
            "Library/Application Support/Cursor/CachedData",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: research, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cursorUser, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cursorCache, withIntermediateDirectories: true)
        try writeSparseFile(research.appendingPathComponent("backtest.parquet"), size: 5_000_000)
        try writeSparseFile(cursorUser.appendingPathComponent("state.json"), size: 1_000_000)
        try writeSparseFile(cursorCache.appendingPathComponent("cache.bin"), size: 2_000_000)

        let result = await SmartCleanupScanner(homeDirectory: temporaryRoot).scan(root: temporaryRoot)
        let rules = RuleEngine(homeDirectory: temporaryRoot)
        let researchNode = try XCTUnwrap(result.root.children.first { $0.path.contains("/quants-lab/output") })
        let userNode = try XCTUnwrap(result.root.children.first { $0.displayName == "Cursor User Data" })
        let cacheNode = try XCTUnwrap(result.root.children.first { $0.displayName == "Cursor CachedData" })

        XCTAssertEqual(rules.classify(researchNode).kind, .researchData)
        XCTAssertFalse(rules.classify(researchNode).level.isQueueable)
        XCTAssertEqual(rules.classify(userNode).kind, .userHistory)
        XCTAssertFalse(rules.classify(userNode).level.isQueueable)
        XCTAssertEqual(rules.classify(cacheNode).level, .rebuildableCache)
        XCTAssertTrue(rules.classify(cacheNode).level.isQueueable)
    }

    private func writeSparseFile(_ url: URL, size: UInt64) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: size)
        try handle.close()
    }
}

private final class CountRecorder: @unchecked Sendable {
    var values: [Int] = []
}
