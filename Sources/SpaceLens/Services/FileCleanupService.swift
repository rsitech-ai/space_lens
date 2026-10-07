import Foundation

public enum CleanupValidationError: LocalizedError, Equatable {
    case missingScanIdentity
    case outsideAuthorizedRoot
    case targetChanged
    case notCleanupReady

    public var errorDescription: String? {
        switch self {
        case .missingScanIdentity:
            "The selected item could not be verified. Rescan the folder before trying again."
        case .outsideAuthorizedRoot:
            "The selected item is outside the folder authorized for cleanup."
        case .targetChanged:
            "The selected item changed after it was scanned. Rescan the folder before trying again."
        case .notCleanupReady:
            "The selected item is not verified as cleanup-ready. Rescan and review it before cleanup."
        }
    }
}

public enum FileCleanupService {
    public typealias ProgressHandler = @Sendable (CleanupProgress) -> Void

    @discardableResult
    public static func moveToBin(
        node: FileNode,
        authorizedRoot: URL,
        reviewedByUser: Bool = false,
        pathUse: PathUseSnapshot? = nil,
        activitySnapshot: (@Sendable () async -> PathUseSnapshot)? = nil,
        progress: ProgressHandler? = nil
    ) async throws -> URL? {
        try await Task.detached(priority: .utility) {
            let url = try validatedCleanupURL(for: node, authorizedRoot: authorizedRoot, reviewedByUser: reviewedByUser, pathUse: pathUse, progress: progress)
            if reviewedByUser, activitySnapshot == nil { throw CleanupValidationError.notCleanupReady }
            if let activitySnapshot {
                // A folder preflight may be lengthy. Refresh after it, immediately before
                // the move, and stop if a tool started while its contents were inspected.
                let fresh = await activitySnapshot()
                guard fresh.activityCheckError == nil else { throw CleanupValidationError.notCleanupReady }
                if reviewedByUser, let previous = pathUse, fresh.hasNewlyRunningTools(comparedTo: previous) {
                    throw CleanupValidationError.notCleanupReady
                }
                _ = try validateCleanupURL(for: node, authorizedRoot: authorizedRoot,
                    reviewedByUser: reviewedByUser, pathUse: fresh, inspectContents: false)
            }
            let totalBytes = allocatedSize(of: url)
            progress?(
                CleanupProgress(
                    phase: .preparing,
                    currentPath: url.path,
                    completedItemCount: 0,
                    totalItemCount: 1,
                    completedBytes: 0,
                    totalBytes: totalBytes
                )
            )

            var resultingItemURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingItemURL)

            progress?(
                CleanupProgress(
                    phase: .finished,
                    currentPath: url.path,
                    completedItemCount: 1,
                    totalItemCount: 1,
                    completedBytes: totalBytes,
                    totalBytes: totalBytes
                )
            )
            return resultingItemURL as URL?
        }.value
    }

    static func isManuallyReviewable(_ node: FileNode, classification: SafetyClassification, pathUse: PathUseSnapshot) -> Bool {
        (classification.level == .unknownReview || classification.level == .largeButValuable)
            && classification.kind != .simulator
            && node.scanError == nil && !node.isSymlink && node.fileIdentity != nil
            && pathUse.activityCheckError == nil
            && DiskScanner.excludedNamespaceReason(node.url) == nil
    }

    static func validatedCleanupURL(
        for node: FileNode, authorizedRoot: URL, reviewedByUser: Bool = false, pathUse: PathUseSnapshot? = nil,
        progress: ProgressHandler? = nil
    ) throws -> URL {
        try validateCleanupURL(for: node, authorizedRoot: authorizedRoot, reviewedByUser: reviewedByUser,
            pathUse: pathUse, inspectContents: true, progress: progress)
    }

    private static func validateCleanupURL(
        for node: FileNode, authorizedRoot: URL, reviewedByUser: Bool, pathUse: PathUseSnapshot?, inspectContents: Bool, progress: ProgressHandler? = nil
    ) throws -> URL {
        let classification = RuleEngine().classify(node, pathUse: pathUse ?? .empty)
        let manual = reviewedByUser && pathUse.map { isManuallyReviewable(node, classification: classification, pathUse: $0) } == true
        guard (classification.level.isQueueable || manual),
              node.rebuildEvidence.isSubset(of: RebuildEvidence.capture(at: node.url)) else {
            throw CleanupValidationError.notCleanupReady
        }
        let authorizedRoot = authorizedRoot.standardizedFileURL.resolvingSymlinksInPath()
        let candidateURL = node.url.standardizedFileURL.resolvingSymlinksInPath()
        let rootPath = authorizedRoot.path
        let descendantPrefix = rootPath == "/" ? rootPath : rootPath + "/"

        let canonicalLevel = RuleEngine().classify(FileNode(url: candidateURL, isDirectory: node.isDirectory,
            logicalSize: 0, allocatedSize: 0, captureIdentity: false), pathUse: pathUse ?? .empty).level
        guard canonicalLevel != .systemCritical, canonicalLevel != .activeOrInUse,
              DiskScanner.excludedNamespaceReason(candidateURL) == nil else {
            throw CleanupValidationError.notCleanupReady
        }
        guard candidateURL.path != rootPath, candidateURL.path.hasPrefix(descendantPrefix) else {
            throw CleanupValidationError.outsideAuthorizedRoot
        }
        guard let scannedIdentity = node.fileIdentity else {
            throw CleanupValidationError.missingScanIdentity
        }
        guard let currentIdentity = FileIdentity.capture(at: node.url),
              !currentIdentity.isSymbolicLink,
              currentIdentity == scannedIdentity else {
            throw CleanupValidationError.targetChanged
        }

        if manual, node.isDirectory, inspectContents {
            try validateManualContents(of: candidateURL, pathUse: pathUse ?? .empty, totalBytes: node.effectiveSize, progress: progress)
            guard FileIdentity.capture(at: node.url) == scannedIdentity,
                  node.url.standardizedFileURL.resolvingSymlinksInPath() == candidateURL else {
                throw CleanupValidationError.targetChanged
            }
        }
        return node.url.standardizedFileURL
    }

    // Display trees are bounded. Independently walk a manual folder so omitted children
    // cannot hide tool-owned storage, protected paths or failed reads.
    private static func validateManualContents(of root: URL, pathUse: PathUseSnapshot, totalBytes: Int64, progress: ProgressHandler?) throws {
        func report(_ url: URL) {
            progress?(CleanupProgress(phase: .checking, currentPath: url.path, completedItemCount: 0,
                totalItemCount: 1, completedBytes: 0, totalBytes: totalBytes))
        }
        report(root)
        var readFailed = false
        guard let enumerator = FileManager.default.enumerator(at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            errorHandler: { _, _ in readFailed = true; return false }) else {
            throw CleanupValidationError.notCleanupReady
        }
        let rules = RuleEngine()
        var visited = 0
        while true {
            try Task.checkCancellation()
            let hasNext = try autoreleasepool { () throws -> Bool in
                guard let url = enumerator.nextObject() as? URL else { return false }
                visited += 1
                if visited % 512 == 0 { report(url) }
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                if values.isSymbolicLink == true { enumerator.skipDescendants(); return true }
                let child = FileNode(url: url, isDirectory: values.isDirectory == true,
                    logicalSize: 0, allocatedSize: 0, captureIdentity: false, rebuildEvidence: RebuildEvidence.capture(at: url))
                let classification = rules.classify(child, pathUse: pathUse)
                guard classification.level != .activeOrInUse, classification.level != .systemCritical,
                      classification.kind != .simulator,
                      DiskScanner.excludedNamespaceReason(url) == nil else {
                    throw CleanupValidationError.notCleanupReady
                }
                return true
            }
            if !hasNext { break }
        }
        if readFailed { throw CleanupValidationError.notCleanupReady }
    }

    private static func allocatedSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .fileSizeKey]) else {
            return 0
        }

        if values.isDirectory == true {
            return Int64(values.fileAllocatedSize ?? values.fileSize ?? 0)
        }

        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
    }
}
