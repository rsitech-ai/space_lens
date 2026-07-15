import Foundation
import XCTest
@testable import SpaceLens

final class RuleEngineTests: XCTestCase {
    private let rules = RuleEngine()

    func testGenericBuildFolderNeedsReview() {
        let node = node(path: "/Users/s1kor/dev/flutter/usafe/mobile/build", isDirectory: true)
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .largeButValuable)
        XCTAssertFalse(classification.level.isQueueable)
    }

    func testPackageCacheIsRebuildable() {
        let node = node(path: "/Users/s1kor/dev/app/.build", isDirectory: true)
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
        let node = node(path: "/Users/s1kor/Library/Application Support/ExampleApp/state.sqlite")
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .unknownReview)
        XCTAssertEqual(classification.category, "App state database")
    }

    func testDockerRawIsActiveToolOwned() {
        let node = node(path: "/Users/s1kor/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw")
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .activeOrInUse)
        XCTAssertEqual(classification.category, "Docker storage")
    }

    func testAIModelStoreIsValuable() {
        let node = node(path: "/Users/s1kor/.lmstudio/models/openai/gpt-oss-120b-MLX-8bit", isDirectory: true)
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .largeButValuable)
        XCTAssertEqual(classification.category, "AI models")
    }

    func testSourceProjectDataIsNotSafe() {
        let node = node(path: "/Users/s1kor/dev/trading/rsibot/quants-lab/app/data/cache/lob", isDirectory: true)
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .unknownReview)
        XCTAssertEqual(classification.category, "Trading research cache")
        XCTAssertFalse(classification.level.isQueueable)
    }

    func testSmartScanSafeCachePathsAreQueueable() {
        let simulatorCache = node(path: "/Library/Developer/CoreSimulator/Caches", isDirectory: true)
        let wallpaperVideos = node(
            path: "/Users/s1kor/Library/Application Support/com.apple.wallpaper/aerials/videos",
            isDirectory: true
        )

        XCTAssertEqual(rules.classify(simulatorCache).level, .rebuildableCache)
        XCTAssertEqual(rules.classify(wallpaperVideos).level, .safeTemp)
    }

    func testSmartScanReviewFirstPathsAreNotQueueable() {
        let condaPackages = node(path: "/Users/s1kor/anaconda3/pkgs", isDirectory: true)
        let codexSessions = node(path: "/Users/s1kor/.codex/sessions", isDirectory: true)
        let cursorHistory = node(
            path: "/Users/s1kor/Library/Application Support/Cursor/User/History",
            isDirectory: true
        )
        let androidDevice = node(path: "/Users/s1kor/.android/avd/Medium_Phone.avd", isDirectory: true)

        for candidate in [condaPackages, codexSessions, cursorHistory, androidDevice] {
            XCTAssertEqual(rules.classify(candidate).level, .unknownReview)
            XCTAssertFalse(rules.classify(candidate).level.isQueueable)
        }
    }

    func testSmartScanDoNotRawDeletePathsStayProtected() {
        let virtualMemory = node(path: "/System/Volumes/VM", isDirectory: true)
        let researchLibrary = node(
            path: "/Users/s1kor/dev/new/alpha-vistula/risercz/python/universal/downloads/library",
            isDirectory: true
        )

        XCTAssertEqual(rules.classify(virtualMemory).level, .systemCritical)
        XCTAssertEqual(rules.classify(researchLibrary).level, .largeButValuable)
    }

    func testCrashpadDumpInTempIsSafeCandidate() {
        let node = node(path: "/private/var/folders/g6/example/com.openai.codex.code_sign_clone/crash.dmp")
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .safeTemp)
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
