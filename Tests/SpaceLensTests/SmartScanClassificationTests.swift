import Foundation
import XCTest
@testable import SpaceLens

final class SmartScanClassificationTests: XCTestCase {
    private let rules = RuleEngine(homeDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true))

    func testKnownCacheRootsAreQueueableAndNotUserData() {
        let cases: [(path: String, kind: ScanKind)] = [
            ("/Users/example/Library/Developer/Xcode/DerivedData", .rebuildableCache),
            ("/Users/example/dev/app/.build", .rebuildableCache),
            ("/Users/example/dev/app/__pycache__", .rebuildableCache),
            ("/Users/example/Library/Caches/Homebrew", .packageCache),
            ("/Users/example/.cargo/registry", .packageCache),
            ("/Users/example/.npm", .packageCache),
            ("/Library/Developer/CoreSimulator/Caches", .rebuildableCache),
            ("/Users/example/Library/Application Support/Cursor/CachedData", .rebuildableCache),
            ("/Users/example/Library/Developer/Xcode/iOS DeviceSupport", .rebuildableCache),
            ("/Users/example/dev/android/app/build/intermediates", .rebuildableCache),
            ("/Users/example/dev/apps/alpha-desk/.worktrees/oss-production/target", .rebuildableCache),
            ("/Users/example/dev/web/node_modules", .packageCache)
        ]

        for item in cases {
            let classification = rules.classify(node(path: item.path, isDirectory: true))
            XCTAssertTrue(
                classification.level.isQueueable,
                "\(item.path) should be cleanup-ready, got \(classification.level) \(classification.category)"
            )
            XCTAssertEqual(classification.kind, item.kind, item.path)
            XCTAssertNotEqual(classification.kind, .userHistory, item.path)
            XCTAssertNotEqual(classification.kind, .researchData, item.path)
        }
    }

    func testConditionalUserDataIsNeverSafeToDelete() {
        let cases: [(path: String, kind: ScanKind)] = [
            ("/Users/example/.codex/sessions", .userHistory),
            ("/Users/example/.codex/worktrees", .userHistory),
            ("/Users/example/Library/Application Support/Cursor/User/History", .userHistory),
            ("/Users/example/Library/Application Support/Cursor/User/globalStorage", .userHistory),
            ("/Users/example/dev/quants-lab/output", .researchData),
            ("/Users/example/Library/Developer/CoreSimulator/Devices", .simulator),
            ("/Users/example/Library/Developer/XCTestDevices", .simulator),
            ("/Users/example/.rustup/toolchains", .toolchain),
            ("/Users/example/dev/tools/.venv", .toolchain),
            ("/Users/example/Library/Developer/Xcode/Archives", .unknownLarge),
            ("/Users/example/Library/Application Support/MobileSync/Backup", .unknownLarge),
            ("/Users/example/Documents/Photos", .unknownLarge)
        ]

        for item in cases {
            let classification = rules.classify(node(path: item.path, isDirectory: true))
            XCTAssertFalse(
                classification.level.isQueueable,
                "\(item.path) must not be treated as safe cache, got \(classification.level) \(classification.category)"
            )
            XCTAssertEqual(classification.kind, item.kind, item.path)
        }
    }

    func testDockerStorageIsToolOwnedAndNotClaimedPruneable() {
        let docker = rules.classify(
            node(
                path: "/Users/example/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw"
            )
        )

        XCTAssertEqual(docker.level, .activeOrInUse)
        XCTAssertEqual(docker.kind, .docker)
        XCTAssertFalse(docker.level.isQueueable)
        XCTAssertTrue(docker.recommendedAction.lowercased().contains("prune") || docker.summary.lowercased().contains("pruneable"))
    }

    func testXcodeProcessMarksDerivedDataAndTmpInUse() {
        let pathUse = PathUseDetector.snapshot(runningProcessNames: ["Xcode", "Cursor", "cargo"])
        XCTAssertTrue(pathUse.xcodeFamilyActive)
        XCTAssertTrue(pathUse.cursorActive)
        XCTAssertTrue(pathUse.cargoActive)

        let derivedData = rules.classify(
            node(path: "/Users/example/Library/Developer/Xcode/DerivedData", isDirectory: true),
            pathUse: pathUse
        )
        let tmp = rules.classify(node(path: "/private/tmp", isDirectory: true), pathUse: pathUse)
        let cursorCache = rules.classify(
            node(path: "/Users/example/Library/Application Support/Cursor/CachedData", isDirectory: true),
            pathUse: pathUse
        )
        let cargoRegistry = rules.classify(
            node(path: "/Users/example/.cargo/registry", isDirectory: true),
            pathUse: pathUse
        )

        XCTAssertEqual(derivedData.level, .activeOrInUse)
        XCTAssertEqual(tmp.level, .activeOrInUse)
        XCTAssertEqual(cursorCache.level, .activeOrInUse)
        XCTAssertEqual(cargoRegistry.level, .activeOrInUse)
        XCTAssertFalse(derivedData.level.isQueueable)
    }

    func testHomeOrRootLsofHandleDoesNotActivateProjectTarget() {
        let pathUse = PathUseDetector.snapshot(
            runningProcessNames: ["node", "Cursor"],
            openPaths: ["/", "/Users", "/Users/example", "/System/Volumes/Data"]
        )
        XCTAssertTrue(pathUse.openPaths.isEmpty)

        let target = rules.classify(
            node(path: "/Users/example/dev/foo/target", isDirectory: true),
            pathUse: pathUse
        )
        XCTAssertEqual(target.level, .rebuildableCache)
        XCTAssertTrue(target.level.isQueueable)
        XCTAssertFalse(PathUseDetector.pathIsOpen(
            "/Users/example/dev/foo/target",
            openPaths: ["/", "/Users/example"]
        ))
    }

    func testNodeProcessesKeepAllDependencyTreesActive() {
        let pathUse = PathUseDetector.snapshot(
            runningProcessNames: ["node"],
            openPaths: [
                "/Users/example",
                "/Users/example/dev/web/node_modules/react/index.js",
                "/Users/example/dev/other/package.json"
            ]
        )
        XCTAssertEqual(
            PathUseDetector.matchingOpenPaths(
                candidatePaths: [
                    "/Users/example/dev/web/node_modules",
                    "/Users/example/dev/other/node_modules"
                ],
                openPaths: pathUse.openPaths
            ),
            ["/Users/example/dev/web/node_modules/react/index.js"]
        )

        let openTree = rules.classify(
            node(path: "/Users/example/dev/web/node_modules", isDirectory: true),
            pathUse: pathUse
        )
        let idleTree = rules.classify(
            node(path: "/Users/example/dev/other/node_modules", isDirectory: true),
            pathUse: pathUse
        )
        XCTAssertEqual(openTree.level, .activeOrInUse)
        XCTAssertFalse(openTree.level.isQueueable)
        XCTAssertEqual(idleTree.level, .activeOrInUse)
        XCTAssertFalse(idleTree.level.isQueueable)
    }

    func testLsofSnapshotMarksOpenPathActive() {
        let parsed = PathUseDetector.parseLsofNameOutput("p431\nn/Users/example/dev/web/node_modules/react\n")
        XCTAssertEqual(parsed, ["/Users/example/dev/web/node_modules/react"])

        let pathUse = PathUseDetector.snapshot(
            runningProcessNames: ["node"],
            openPaths: ["/Users/example/dev/web/node_modules"]
        )
        XCTAssertTrue(pathUse.nodePackageActive)

        let classification = rules.classify(
            node(path: "/Users/example/dev/web/node_modules", isDirectory: true),
            pathUse: pathUse
        )
        XCTAssertEqual(classification.level, .activeOrInUse)
        XCTAssertFalse(classification.level.isQueueable)
        XCTAssertEqual(classification.kind, .packageCache)
    }

    func testSimctlJSONProducesBootedAndUnavailableDeviceRows() throws {
        let json = Data("""
        {
          "devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-17-5": [
              {
                "udid": "AAA",
                "name": "iPhone 15",
                "state": "Booted",
                "isAvailable": true,
                "dataPath": "/Users/example/Library/Developer/CoreSimulator/Devices/AAA/data"
              },
              {
                "udid": "BBB",
                "name": "iPhone 8",
                "state": "Shutdown",
                "isAvailable": false,
                "dataPath": "/Users/example/Library/Developer/CoreSimulator/Devices/BBB/data"
              }
            ]
          }
        }
        """.utf8)
        let inventory = try SimulatorInventory.parse(json: json)
        XCTAssertEqual(inventory.devices.count, 2)
        XCTAssertTrue(inventory.devices.contains { $0.isBooted && $0.name == "iPhone 15" })
        XCTAssertTrue(inventory.devices.contains { !$0.isAvailable && $0.name == "iPhone 8" })

        let pathUse = PathUseSnapshot(
            runningToolLabels: [],
            xcodeFamilyActive: false,
            dockerActive: false,
            cursorActive: false,
            cargoActive: false,
            simulatorInventory: inventory
        )
        let booted = rules.classify(
            node(path: "/Users/example/Library/Developer/CoreSimulator/Devices/AAA/data", isDirectory: true),
            pathUse: pathUse
        )
        let unavailable = rules.classify(
            node(path: "/Users/example/Library/Developer/CoreSimulator/Devices/BBB/data", isDirectory: true),
            pathUse: pathUse
        )
        XCTAssertEqual(booted.level, .activeOrInUse)
        XCTAssertEqual(unavailable.kind, .simulator)
        XCTAssertFalse(unavailable.level.isQueueable)
        XCTAssertTrue(unavailable.recommendedAction.lowercased().contains("unavailable"))
    }

    func testIdleProcessesLeaveRebuildableCachesQueueable() {
        let derivedData = rules.classify(
            node(path: "/Users/example/Library/Developer/Xcode/DerivedData", isDirectory: true),
            pathUse: .empty
        )

        XCTAssertEqual(derivedData.level, .rebuildableCache)
        XCTAssertTrue(derivedData.level.isQueueable)
    }

    func testSummarySeparatesConservativeTheoreticalAndAuditNote() async {
        let snapshot = ScanSnapshot(
            rootPath: "/Users/example",
            startedAt: Date(),
            completedAt: Date(),
            totalLogicalSize: 500,
            totalAllocatedSize: 500,
            nodeCount: 2,
            errorCount: 0
        )
        let cache = FileNode(
            url: URL(fileURLWithPath: "/Users/example/.build"),
            isDirectory: true,
            logicalSize: 200,
            allocatedSize: 200
        )
        let conda = FileNode(
            url: URL(fileURLWithPath: "/Users/example/anaconda3/pkgs"),
            isDirectory: true,
            logicalSize: 300,
            allocatedSize: 300
        )
        let items = [
            ClassifiedScanItem(node: cache, classification: rules.classify(cache)),
            ClassifiedScanItem(node: conda, classification: rules.classify(conda))
        ]
        let pressure = VolumePressure(
            volumePath: "/",
            volumeName: "Data",
            totalBytes: 1_000_000_000_000,
            availableBytes: 266_000_000,
            importantAvailableBytes: 1_000_000_000,
            opportunisticAvailableBytes: 266_000_000
        )

        let summary = await LocalIntelligenceService().summarizeScan(
            snapshot: snapshot,
            items: items,
            context: ScanSummaryContext(volumePressure: pressure)
        )

        XCTAssertEqual(summary.recoverableBytes, 200)
        XCTAssertEqual(summary.theoreticalRecoverableBytes, 500)
        XCTAssertEqual(summary.auditNote, "No files were removed.")
        XCTAssertTrue(summary.title.contains("immediately available"))
        XCTAssertTrue(summary.body.contains("Conservative cleanup"))
        XCTAssertTrue(summary.nextStep.contains("/tmp"))
        XCTAssertTrue(pressure.isUnderPressure)
    }

    func testBoundedProcessStopsWhenTaskIsCancelled() async throws {
        let started = Date()
        let task = Task {
            await BoundedProcess.run(executable: "/bin/sleep", arguments: ["8"], timeout: 20)
        }
        try await Task.sleep(nanoseconds: 80_000_000)
        task.cancel()
        _ = await task.value
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    }

    func testCatalogTemplatesCoverRequiredCacheFamilies() {
        let templates = (SmartScanCatalog.homeTemplates + SmartScanCatalog.volumeWideTemplates)
            .map(\.template)
            .joined(separator: "\n")

        for needle in [
            "DerivedData",
            "CoreSimulator",
            "Homebrew",
            ".npm",
            "pnpm",
            ".cargo/registry",
            ".rustup/toolchains",
            "com.docker.docker",
            "Cursor/CachedData",
            "Cursor/User",
            ".codex/sessions",
            ".codex/worktrees",
            "MobileSync/Backup",
            ".Trash",
            "/private/tmp",
            "iOS DeviceSupport",
            "Archives",
            "XCTestDevices"
        ] {
            XCTAssertTrue(templates.contains(needle), "catalog missing \(needle)")
        }
    }

    private func node(path: String, isDirectory: Bool = true) -> FileNode {
        FileNode(
            url: URL(fileURLWithPath: path),
            isDirectory: isDirectory,
            logicalSize: 2_000_000_000,
            allocatedSize: 2_000_000_000,
            rebuildEvidence: URL(fileURLWithPath: path).lastPathComponent == "target" ? [.cargoManifest]
                : (URL(fileURLWithPath: path).lastPathComponent == "intermediates" ? [.gradleManifest]
                    : (URL(fileURLWithPath: path).lastPathComponent == "node_modules" ? [.packageLockfile] : []))
        )
    }
}
