import Foundation

public protocol IntelligenceService: Sendable {
    func explain(node: FileNode, classification: SafetyClassification) async -> IntelligenceExplanation
    func summarizeScan(snapshot: ScanSnapshot, items: [ClassifiedScanItem]) async -> ScanIntelligenceSummary
}

public struct LocalIntelligenceService: IntelligenceService {
    public init() {}

    public func explain(node: FileNode, classification: SafetyClassification) async -> IntelligenceExplanation {
        let size = ByteFormat.string(node.effectiveSize)
        let evidence = classification.evidence.joined(separator: " ")

        let safetyAnswer: String
        switch classification.level {
        case .safeTemp:
            safetyAnswer = "Likely safe to remove after review because it matches a disposable temp pattern."
        case .rebuildableCache:
            safetyAnswer = "Usually safe to remove after review because the owning tool can rebuild it."
        case .generatedOutput:
            safetyAnswer = "Potentially removable after review because it looks generated from source or prior runs."
        case .largeButValuable:
            safetyAnswer = "Not treated as safe. It may be intentional user or project data."
        case .activeOrInUse:
            safetyAnswer = "Not safe to delete directly. Use the owning tool or stop the process first."
        case .systemCritical:
            safetyAnswer = "Not safe. SpaceLens will not recommend cleanup for this location."
        case .unknownReview:
            safetyAnswer = "Unknown. SpaceLens needs a human review before any cleanup."
        }

        return IntelligenceExplanation(
            title: "\(node.displayName) is using \(size)",
            body: "\(classification.summary) \(evidence)",
            safetyAnswer: safetyAnswer,
            nextStep: classification.recommendedAction
        )
    }

    public func summarizeScan(snapshot: ScanSnapshot, items: [ClassifiedScanItem]) async -> ScanIntelligenceSummary {
        let statistics = ScanStatistics(snapshot: snapshot, items: items)
        let recoverable = ByteFormat.string(statistics.queueableBytes)
        let total = ByteFormat.string(snapshot.totalAllocatedSize)

        let title: String
        if statistics.queueableBytes > 0 {
            title = "Found \(recoverable) of low-risk cleanup candidates"
        } else {
            title = "No low-risk cleanup candidates yet"
        }

        let body = [
            "\(snapshot.nodeCount) items scanned across \(total).",
            "\(statistics.reviewCount) need human review.",
            "\(statistics.activeCount + statistics.protectedCount) are active, tool-owned, or protected."
        ].joined(separator: " ")

        let nextStep: String
        if statistics.queueableCount > 0 {
            nextStep = "Review the safe candidate bucket, then add only confirmed rebuildable items to the queue."
        } else if statistics.reviewCount > 0 {
            nextStep = "Inspect the largest review items before queuing anything."
        } else {
            nextStep = "Rescan a broader folder if you expected more disk pressure."
        }

        return ScanIntelligenceSummary(
            title: title,
            body: body,
            nextStep: nextStep,
            confidence: statistics.averageConfidence,
            recoverableBytes: statistics.queueableBytes,
            reviewCount: statistics.reviewCount,
            protectedCount: statistics.protectedCount
        )
    }
}
