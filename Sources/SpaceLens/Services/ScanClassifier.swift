import Foundation

/// Keep classification cooperative even when a scan contains many retained candidates.
enum ScanClassifier {
    static func classify(
        nodes: [FlattenedFileNode],
        snapshot: ScanSnapshot,
        ruleEngine: RuleEngine,
        pathUse: PathUseSnapshot,
        onProgress: @escaping @Sendable (ScanProgress) -> Void
    ) async -> [ClassifiedScanItem]? {
        var items: [ClassifiedScanItem] = []
        items.reserveCapacity(nodes.count)
        var lastUpdate = Date.distantPast
        for (index, item) in nodes.enumerated() {
            guard !Task.isCancelled else { return nil }
            if index.isMultiple(of: 128) {
                let now = Date()
                if now.timeIntervalSince(lastUpdate) >= 0.1 {
                    onProgress(ScanProgress(snapshot: snapshot, phase: .classifying, processed: index, total: nodes.count))
                    lastUpdate = now
                }
                await Task.yield()
                guard !Task.isCancelled else { return nil }
            }
            items.append(ClassifiedScanItem(
                node: item.node,
                classification: ruleEngine.classify(item.node, pathUse: pathUse)
            ))
        }
        guard !Task.isCancelled else { return nil }
        onProgress(ScanProgress(snapshot: snapshot, phase: .classifying, processed: nodes.count, total: nodes.count))
        return items
    }
}
