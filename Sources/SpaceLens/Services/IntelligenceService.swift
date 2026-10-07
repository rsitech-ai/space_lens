import Foundation

public protocol IntelligenceService: Sendable {
    func explain(node: FileNode, classification: SafetyClassification) async -> IntelligenceExplanation
    func summarizeScan(
        snapshot: ScanSnapshot,
        items: [ClassifiedScanItem],
        context: ScanSummaryContext
    ) async -> ScanIntelligenceSummary
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

    public func summarizeScan(
        snapshot: ScanSnapshot,
        items: [ClassifiedScanItem],
        context: ScanSummaryContext
    ) async -> ScanIntelligenceSummary {
        let statistics = ScanStatistics(snapshot: snapshot, items: items)
        let conservativeRoots = CleanupTargetNormalizer.collapsingDescendants(
            items.filter { $0.classification.level.isQueueable },
            url: { $0.node.url }
        )
        let theoreticalRoots = CleanupTargetNormalizer.collapsingDescendants(
            items.filter { item in
                if item.classification.level.isQueueable {
                    return true
                }
                if item.classification.level == .activeOrInUse, item.classification.kind.countsTowardTheoreticalRecovery {
                    return true
                }
                return item.node.scanError == nil && item.classification.level == .unknownReview
                    && item.classification.kind.countsTowardTheoreticalRecovery
            },
            url: { $0.node.url }
        )
        let conservativeBytes = conservativeRoots.reduce(Int64(0)) { $0 + $1.node.effectiveSize }
        let theoreticalBytes = theoreticalRoots.reduce(Int64(0)) { $0 + $1.node.effectiveSize }
        let recoverable = ByteFormat.string(conservativeBytes)
        let theoretical = ByteFormat.string(theoreticalBytes)
        let total = ByteFormat.string(snapshot.totalAllocatedSize)
        let auditNote = context.didRemoveFiles ? "This pass changed files." : "No files were removed."

        let topCandidates = conservativeRoots
            .sorted { $0.node.effectiveSize > $1.node.effectiveSize }
            .prefix(4)
            .map { "\($0.node.displayName) (\(ByteFormat.string($0.node.effectiveSize)))" }

        let title: String
        if let volumeHeadline = context.volumePressure?.headline {
            title = volumeHeadline
        } else if conservativeBytes > 0 {
            title = "Found \(recoverable) of low-risk cleanup candidates"
        } else {
            title = "No low-risk cleanup candidates yet"
        }

        var bodyParts: [String] = []
        if context.volumePressure == nil {
            bodyParts.append("\(snapshot.nodeCount) items scanned across \(total).")
        } else {
            bodyParts.append("Scan visited \(snapshot.nodeCount) items; displayed candidates total \(total).")
        }
        bodyParts.append("Conservative cleanup \(recoverable) across \(conservativeRoots.count) rebuildable/temp roots.")
        if theoreticalBytes > conservativeBytes {
            bodyParts.append("Theoretical \(theoretical) if inactive package caches are pruned after review.")
        }
        bodyParts.append("\(statistics.reviewCount) conditional items (history, research, toolchains, simulators) need a human decision.")
        bodyParts.append("\(statistics.activeCount + statistics.protectedCount) are active, tool-owned, or protected.")
        if snapshot.errorCount > 0 {
            bodyParts.append("\(snapshot.errorCount) scan errors; open Scan Errors for paths SpaceLens could not read.")
        }
        if !topCandidates.isEmpty {
            bodyParts.append("Best cleanup candidates: \(topCandidates.joined(separator: "; ")).")
        }
        if let simctlError = context.pathUse.simulatorInventory.error {
            bodyParts.append("simctl inventory failed: \(simctlError).")
        } else if !context.pathUse.simulatorInventory.devices.isEmpty {
            let devices = context.pathUse.simulatorInventory.devices
            let booted = devices.filter(\.isBooted).count
            let unavailable = devices.filter { !$0.isAvailable }.count
            let rows = devices.prefix(12).map { device in
                "\(device.name) \(device.state)\(device.isAvailable ? "" : " unavailable")"
            }
            bodyParts.append("simctl \(devices.count) devices (\(booted) Booted, \(unavailable) unavailable): \(rows.joined(separator: "; ")).")
        }
        let documentHits = items
            .filter { SmartScanCatalog.isUserContentPath($0.node.path) && $0.classification.kind == .unknownLarge }
            .sorted { $0.node.effectiveSize > $1.node.effectiveSize }
            .prefix(SmartScanCatalog.documentsInventoryLimit)
        if !documentHits.isEmpty {
            let rows = documentHits.map { "\($0.node.displayName) (\(ByteFormat.string($0.node.effectiveSize)))" }
            bodyParts.append("Documents/user-content large items: \(rows.joined(separator: "; ")).")
        }
        if !context.pendingDiscoveryPaths.isEmpty {
            bodyParts.append("Scan still pending \(context.pendingDiscoveryPaths.count) folders (time budget); not silently omitted: \(context.pendingDiscoveryPaths.prefix(8).joined(separator: "; ")).")
        }

        var nextStep: String
        if conservativeRoots.count > 0 {
            nextStep = "Review conservative cleanup-ready items in the table or Cleanup Queue. Confirm every path before Move to Bin. Close Xcode, Simulator, Docker, and Cursor before deleting in-use roots."
        } else if statistics.reviewCount > 0 {
            nextStep = "Inspect the largest review items before queuing anything. Research outputs, Cursor User data, Codex sessions/worktrees, and usable simulators stay conditional."
        } else {
            nextStep = "Rescan a broader folder if you expected more disk pressure."
        }
        let includedTemporaryRoot = items.contains { item in
            let path = item.node.path.lowercased()
            return path == "/tmp" || path == "/private/tmp" || path.hasPrefix("/private/tmp/") || path.hasPrefix("/tmp/")
        }
        if !includedTemporaryRoot {
            nextStep += " This scan did not include /tmp; select that folder to review individual temporary files."
        }

        var processCaveats = context.pathUse.caveats
        let lsofHits = PathUseDetector.mappedHitCount(
            candidatePaths: items.map(\.node.path),
            openPaths: context.pathUse.openPaths
        )
        if lsofHits > 0 {
            processCaveats.append("lsof snapshot marked \(lsofHits) scan hits Active.")
        }

        return ScanIntelligenceSummary(
            title: title,
            body: bodyParts.joined(separator: " "),
            nextStep: nextStep,
            confidence: statistics.averageConfidence,
            recoverableBytes: conservativeBytes,
            theoreticalRecoverableBytes: theoreticalBytes,
            reviewCount: statistics.reviewCount,
            protectedCount: statistics.protectedCount,
            volumeHeadline: context.volumePressure?.headline,
            immediatelyAvailableBytes: context.volumePressure.map {
                $0.opportunisticAvailableBytes > 0 ? $0.opportunisticAvailableBytes : $0.availableBytes
            },
            auditNote: auditNote,
            processCaveats: processCaveats
        )
    }
}
