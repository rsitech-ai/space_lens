import Foundation
import XCTest
@testable import SpaceLens

final class IntelligenceServiceTests: XCTestCase {
    func testLocalIntelligenceSummarizesScanFromClassifiedItems() async throws {
        let snapshot = ScanSnapshot(
            rootPath: "/tmp/SpaceLens",
            startedAt: Date(),
            completedAt: Date(),
            totalLogicalSize: 600,
            totalAllocatedSize: 600,
            nodeCount: 3,
            errorCount: 0
        )
        let cache = FileNode(
            url: URL(fileURLWithPath: "/tmp/SpaceLens/.build"),
            isDirectory: true,
            logicalSize: 400,
            allocatedSize: 400
        )
        let source = FileNode(
            url: URL(fileURLWithPath: "/tmp/SpaceLens/main.swift"),
            isDirectory: false,
            logicalSize: 200,
            allocatedSize: 200
        )
        let items = [
            ClassifiedScanItem(
                node: cache,
                classification: SafetyClassification(
                    level: .rebuildableCache,
                    confidence: 0.9,
                    category: "Package/build cache",
                    summary: "Cache",
                    evidence: [],
                    recommendedAction: "Queue for review."
                )
            ),
            ClassifiedScanItem(
                node: source,
                classification: SafetyClassification(
                    level: .unknownReview,
                    confidence: 0.5,
                    category: "Unknown",
                    summary: "Review",
                    evidence: [],
                    recommendedAction: "Review only."
                )
            )
        ]

        let summary = await LocalIntelligenceService().summarizeScan(snapshot: snapshot, items: items)

        XCTAssertEqual(summary.recoverableBytes, 400)
        XCTAssertEqual(summary.reviewCount, 1)
        XCTAssertEqual(summary.protectedCount, 0)
        XCTAssertEqual(summary.confidence, 0.7, accuracy: 0.001)
        XCTAssertTrue(summary.title.contains("low-risk cleanup candidates"))
        XCTAssertTrue(summary.body.contains("3 items scanned"))
    }
}
