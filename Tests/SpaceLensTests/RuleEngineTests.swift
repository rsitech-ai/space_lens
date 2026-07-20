import Foundation
import XCTest
@testable import SpaceLens

final class RuleEngineTests: XCTestCase {
    private let rules = RuleEngine()

    func testGenericBuildFolderNeedsReview() {
        let node = node(path: "/Users/example/dev/MobileApp/build", isDirectory: true)
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .largeButValuable)
        XCTAssertFalse(classification.level.isQueueable)
    }

    func testPackageCacheIsRebuildable() {
        let node = node(path: "/Users/example/Projects/SampleApp/.build", isDirectory: true)
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .rebuildableCache)
    }

    func testNestedLibraryCachesDirectoryIsNotRebuildable() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let nestedCache = node(
            path: homeDirectory.appendingPathComponent("Documents/Project/Library/Caches/Photos").path,
            isDirectory: true
        )

        XCTAssertFalse(rules.classify(nestedCache).level.isQueueable)
    }

    func testScanErrorCannotBecomeQueueableFromCacheName() {
        let unreadableCache = node(
            path: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/com.example.opaque").path,
            isDirectory: true,
            scanError: "Permission denied"
        )

        let classification = rules.classify(unreadableCache)

        XCTAssertEqual(classification.level, .unknownReview)
        XCTAssertEqual(classification.category, "Incomplete scan")
    }

    func testSymlinkCannotBecomeQueueableFromCacheName() {
        let cacheLink = node(
            path: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/com.example.link").path,
            isDirectory: true,
            isSymlink: true
        )

        XCTAssertFalse(rules.classify(cacheLink).level.isQueueable)
    }

    func testApplicationSupportDatabaseNeedsReview() {
        let node = node(path: "/Users/example/Library/Application Support/ExampleApp/state.sqlite")
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .unknownReview)
        XCTAssertEqual(classification.category, "App state database")
    }

    func testDockerRawIsActiveToolOwned() {
        let node = node(path: "/Users/example/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw")
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .activeOrInUse)
        XCTAssertEqual(classification.category, "Docker storage")
    }

    func testAIModelStoreIsValuable() {
        let node = node(path: "/Users/example/.lmstudio/models/example-model", isDirectory: true)
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .largeButValuable)
        XCTAssertEqual(classification.category, "AI models")
    }

    func testResearchDataCacheIsNotSafe() {
        let node = node(
            path: "/Users/example/dev/research-experiments/app/data/cache/orderbook",
            isDirectory: true
        )
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .unknownReview)
        XCTAssertEqual(classification.category, "Research data cache")
        XCTAssertFalse(classification.level.isQueueable)
    }

    func testSmartScanSafeCachePathsAreQueueable() {
        let simulatorCache = node(path: "/Library/Developer/CoreSimulator/Caches", isDirectory: true)
        let wallpaperVideos = node(
            path: "/Users/example/Library/Application Support/com.apple.wallpaper/aerials/videos",
            isDirectory: true
        )

        XCTAssertEqual(rules.classify(simulatorCache).level, .rebuildableCache)
        XCTAssertEqual(rules.classify(wallpaperVideos).level, .safeTemp)
    }

    func testSmartScanReviewFirstPathsAreNotQueueable() {
        let condaPackages = node(path: "/Users/example/anaconda3/pkgs", isDirectory: true)
        let codexSessions = node(path: "/Users/example/.codex/sessions", isDirectory: true)
        let cursorHistory = node(
            path: "/Users/example/Library/Application Support/Cursor/User/History",
            isDirectory: true
        )
        let androidDevice = node(path: "/Users/example/.android/avd/Medium_Phone.avd", isDirectory: true)

        for candidate in [condaPackages, codexSessions, cursorHistory, androidDevice] {
            XCTAssertEqual(rules.classify(candidate).level, .unknownReview)
            XCTAssertFalse(rules.classify(candidate).level.isQueueable)
        }
    }

    func testSmartScanDoNotRawDeletePathsStayProtected() {
        let virtualMemory = node(path: "/System/Volumes/VM", isDirectory: true)
        let researchLibrary = node(
            path: "/Users/example/Downloads/ResearchLibrary",
            isDirectory: true
        )

        XCTAssertEqual(rules.classify(virtualMemory).level, .systemCritical)
        XCTAssertEqual(rules.classify(researchLibrary).level, .largeButValuable)
        XCTAssertEqual(rules.classify(researchLibrary).category, "Research corpus")
    }

    func testCrashpadDumpInTempIsSafeCandidate() {
        let node = node(path: "/private/var/folders/g6/example/com.openai.codex.code_sign_clone/crash.dmp")
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .safeTemp)
    }

    func testOldLogInUserDocumentsStillRequiresReview() {
        let node = node(path: "/Users/example/Documents/annual-report.log")

        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .unknownReview)
        XCTAssertFalse(classification.level.isQueueable)
    }

    private func node(
        path: String,
        isDirectory: Bool = false,
        isSymlink: Bool = false,
        scanError: String? = nil
    ) -> FileNode {
        FileNode(
            url: URL(fileURLWithPath: path),
            isDirectory: isDirectory,
            isSymlink: isSymlink,
            logicalSize: 2_000_000_000,
            allocatedSize: 2_000_000_000,
            modifiedAt: Date(timeIntervalSinceNow: -30 * 24 * 60 * 60),
            createdAt: Date(timeIntervalSinceNow: -60 * 24 * 60 * 60),
            scanError: scanError
        )
    }
}
