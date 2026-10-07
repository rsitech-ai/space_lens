import Foundation
import XCTest
@testable import SpaceLens

final class ScanClassifierTests: XCTestCase {
    private func nodes(count: Int) -> [FlattenedFileNode] {
        (0..<count).map { index in
            FlattenedFileNode(node: FileNode(
                url: URL(fileURLWithPath: "/tmp/SpaceLens-classifier/f\(index).txt"),
                isDirectory: false, logicalSize: 1, allocatedSize: 1, captureIdentity: false
            ), depth: 1)
        }
    }

    private var snapshot: ScanSnapshot {
        ScanSnapshot(rootPath: "/tmp/SpaceLens-classifier", startedAt: Date(), completedAt: Date(),
                     totalLogicalSize: 10_000, totalAllocatedSize: 10_000, nodeCount: 10_001,
                     fileCount: 10_000, directoryCount: 1, errorCount: 2)
    }

    func testCancellationDuringClassificationStopsWithoutReturningPartialResults() async {
        let nodes = nodes(count: 10_000)
        let snapshot = snapshot
        let task = Task {
            await ScanClassifier.classify(nodes: nodes, snapshot: snapshot, ruleEngine: RuleEngine(), pathUse: .empty) { progress in
                if progress.phase == .classifying {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            }
        }
        let result = await task.value
        XCTAssertNil(result)
    }

    func testClassificationMatchesRulesAndPreservesTraversalCountsInProgress() async throws {
        let nodes = nodes(count: 1_000)
        let recorder = ClassifierProgressRecorder()
        let engine = RuleEngine()
        let result = await ScanClassifier.classify(nodes: nodes, snapshot: snapshot, ruleEngine: engine, pathUse: .empty) {
            recorder.record($0)
        }
        let items = try XCTUnwrap(result)
        XCTAssertEqual(items.count, nodes.count)
        XCTAssertEqual(items.map(\.classification), nodes.map { engine.classify($0.node, pathUse: .empty) })
        let progress = try XCTUnwrap(recorder.updates.last)
        XCTAssertEqual(progress.phase, .classifying)
        XCTAssertEqual(progress.processedCandidateCount, 1_000)
        XCTAssertEqual(progress.totalCandidateCount, 1_000)
        XCTAssertEqual(progress.scannedCount, 10_001)
        XCTAssertEqual(progress.fileCount, 10_000)
        XCTAssertEqual(progress.errorCount, 2)
        XCTAssertLessThan(recorder.updates.count, 20)
    }
}

private final class ClassifierProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ScanProgress] = []
    var updates: [ScanProgress] { lock.withLock { storage } }
    func record(_ value: ScanProgress) { lock.withLock { storage.append(value) } }
}
