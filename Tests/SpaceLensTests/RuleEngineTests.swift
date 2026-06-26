import Foundation
import XCTest
@testable import SpaceLens

final class RuleEngineTests: XCTestCase {
    private let rules = RuleEngine()

    func testBuildFolderIsGeneratedOutput() {
        let node = node(path: "/Users/s1kor/dev/flutter/usafe/mobile/build", isDirectory: true)
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .generatedOutput)
        XCTAssertEqual(classification.category, "Generated output")
    }

    func testPackageCacheIsRebuildable() {
        let node = node(path: "/Users/s1kor/dev/app/.build", isDirectory: true)
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .rebuildableCache)
    }

    func testApplicationSupportDatabaseNeedsReview() {
        let node = node(path: "/Users/s1kor/Library/Application Support/Cursor/User/globalStorage/state.vscdb")
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

        XCTAssertEqual(classification.level, .largeButValuable)
        XCTAssertFalse(classification.level.isQueueable)
    }

    func testCrashpadDumpInTempIsSafeCandidate() {
        let node = node(path: "/private/var/folders/g6/example/com.openai.codex.code_sign_clone/crash.dmp")
        let classification = rules.classify(node)

        XCTAssertEqual(classification.level, .safeTemp)
    }

    private func node(path: String, isDirectory: Bool = false) -> FileNode {
        FileNode(
            url: URL(fileURLWithPath: path),
            isDirectory: isDirectory,
            logicalSize: 2_000_000_000,
            allocatedSize: 2_000_000_000,
            modifiedAt: Date(timeIntervalSinceNow: -30 * 24 * 60 * 60),
            createdAt: Date(timeIntervalSinceNow: -60 * 24 * 60 * 60)
        )
    }
}
