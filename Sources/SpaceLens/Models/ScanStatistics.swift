import Foundation

public struct ClassifiedScanItem: Hashable, Sendable {
    public let node: FileNode
    public let classification: SafetyClassification

    public init(node: FileNode, classification: SafetyClassification) {
        self.node = node
        self.classification = classification
    }
}

public struct ScanStatistics: Hashable, Sendable {
    public let totalItems: Int
    public let fileCount: Int
    public let directoryCount: Int
    public let symlinkCount: Int
    public let errorCount: Int
    public let totalAllocatedBytes: Int64
    public let queueableCount: Int
    public let queueableBytes: Int64
    public let reviewCount: Int
    public let protectedCount: Int
    public let activeCount: Int
    public let valuableCount: Int
    public let averageConfidence: Double
    public let largestItemName: String
    public let largestItemBytes: Int64
    public let levelCounts: [SafetyLevel: Int]

    public init(snapshot: ScanSnapshot, items: [ClassifiedScanItem]) {
        totalItems = snapshot.nodeCount
        errorCount = snapshot.errorCount
        totalAllocatedBytes = snapshot.totalAllocatedSize
        let queueableRoots = CleanupTargetNormalizer.collapsingDescendants(
            items.filter { $0.classification.level.isQueueable },
            url: { $0.node.url }
        )

        var retainedFileCount = 0
        var retainedDirectoryCount = 0
        var retainedSymlinkCount = 0
        var reviewCount = 0
        var protectedCount = 0
        var activeCount = 0
        var valuableCount = 0
        var confidenceTotal = 0.0
        var largestItemName = "No files"
        var largestItemBytes: Int64 = 0
        var levelCounts: [SafetyLevel: Int] = [:]

        for item in items {
            if item.node.isDirectory {
                retainedDirectoryCount += 1
            } else {
                retainedFileCount += 1
            }
            if item.node.isSymlink {
                retainedSymlinkCount += 1
            }

            let level = item.classification.level
            levelCounts[level, default: 0] += 1

            switch level {
            case .unknownReview:
                reviewCount += 1
            case .systemCritical:
                protectedCount += 1
            case .activeOrInUse:
                activeCount += 1
            case .largeButValuable:
                valuableCount += 1
            case .safeTemp, .rebuildableCache, .generatedOutput:
                break
            }

            confidenceTotal += item.classification.confidence
            let itemBytes = item.node.effectiveSize
            if itemBytes > largestItemBytes {
                largestItemBytes = itemBytes
                largestItemName = item.node.displayName
            }
        }

        self.fileCount = snapshot.fileCount > 0 ? snapshot.fileCount : retainedFileCount
        self.directoryCount = snapshot.directoryCount > 0 ? snapshot.directoryCount : retainedDirectoryCount
        self.symlinkCount = snapshot.symlinkCount > 0 ? snapshot.symlinkCount : retainedSymlinkCount
        self.queueableCount = queueableRoots.count
        self.queueableBytes = queueableRoots.reduce(Int64(0)) { $0 + $1.node.effectiveSize }
        self.reviewCount = reviewCount
        self.protectedCount = protectedCount
        self.activeCount = activeCount
        self.valuableCount = valuableCount
        averageConfidence = items.isEmpty ? 0 : confidenceTotal / Double(items.count)
        self.largestItemName = largestItemName
        self.largestItemBytes = largestItemBytes
        self.levelCounts = levelCounts
    }

    public func count(for level: SafetyLevel) -> Int {
        levelCounts[level, default: 0]
    }

}
