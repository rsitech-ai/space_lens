import Foundation
import XCTest
@testable import SpaceLens

final class AppStateScanTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceLensAppStateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
    }

    @MainActor
    func testStartScanPublishesStatisticsAndIntelligenceSummary() async throws {
        let buildFolder = temporaryRoot.appendingPathComponent(".build", isDirectory: true)
        try FileManager.default.createDirectory(at: buildFolder, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 256).write(to: buildFolder.appendingPathComponent("artifact.o"))

        let appState = AppState()
        appState.startScan(root: temporaryRoot)

        for _ in 0..<100 where appState.isScanning {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertFalse(appState.isScanning)
        XCTAssertNotNil(appState.rootNode)
        XCTAssertNotNil(appState.snapshot)
        XCTAssertNotNil(appState.scanStatistics)
        XCTAssertNotNil(appState.scanIntelligenceSummary)
        XCTAssertGreaterThan(appState.scanStatistics?.queueableCount ?? 0, 0)
        XCTAssertGreaterThan(appState.scanIntelligenceSummary?.recoverableBytes ?? 0, 0)
    }
}
