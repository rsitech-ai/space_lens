import Foundation

public final class DiskScanner {
    public typealias ProgressHandler = @Sendable (ScanProgress) -> Void

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func scan(
        root rootURL: URL,
        options: ScanOptions = .appDefault,
        progress: ProgressHandler? = nil
    ) async -> ScanResult {
        if Task.isCancelled {
            return ScanResult(
                root: placeholderNode(url: rootURL.standardizedFileURL, error: "Scan cancelled"),
                snapshot: ScanSnapshot(
                    rootPath: rootURL.standardizedFileURL.path,
                    startedAt: Date(),
                    completedAt: Date(),
                    totalLogicalSize: 0,
                    totalAllocatedSize: 0,
                    nodeCount: 0,
                    errorCount: 0
                )
            )
        }
        await Task.yield()
        let startedAt = Date()
        var context = ScanContext(startedAt: startedAt, resolvedRootPath: rootURL.standardizedFileURL.resolvingSymlinksInPath().path)
        let rootURL = rootURL.standardizedFileURL
        if Task.isCancelled {
            return ScanResult(
                root: placeholderNode(url: rootURL, error: "Scan cancelled"),
                snapshot: ScanSnapshot(
                    rootPath: rootURL.path,
                    startedAt: startedAt,
                    completedAt: Date(),
                    totalLogicalSize: 0,
                    totalAllocatedSize: 0,
                    nodeCount: 0,
                    errorCount: 0
                )
            )
        }
        let root = scanNode(rootURL, context: &context, options: options, nodeBudget: options.maxRetainedNodes, progress: progress)
        emitProgress(url: rootURL, context: &context, progress: progress, force: true)
        let completedAt = Date()

        return ScanResult(
            root: root,
            snapshot: ScanSnapshot(
                rootPath: root.path,
                startedAt: startedAt,
                completedAt: completedAt,
                totalLogicalSize: root.logicalSize,
                totalAllocatedSize: root.allocatedSize,
                nodeCount: context.nodeCount,
                fileCount: context.fileCount,
                directoryCount: context.directoryCount,
                symlinkCount: context.symlinkCount,
                errorCount: context.errorCount,
                retainedNodeCount: root.flattened().count
            ),
            createdNodeCount: context.createdNodeCount
        )
    }

    private func scanNode(
        _ url: URL,
        context: inout ScanContext,
        options: ScanOptions,
        nodeBudget: Int?,
        progress: ProgressHandler?
    ) -> FileNode {
        if Task.isCancelled {
            return placeholderNode(url: url, error: "Scan cancelled")
        }

        context.nodeCount += 1
        if let issue = Self.excludedNamespaceReason(url) {
            context.errorCount += 1
            let isDirectory = ["/dev", "/.nofollow", "/.resolve"].contains(url.path)
            if isDirectory { context.directoryCount += 1 }
            return makeNode(
                url: url, isDirectory: isDirectory, logicalSize: 0, allocatedSize: 0,
                scanError: issue, context: &context
            )
        }

        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
            .contentModificationDateKey,
            .creationDateKey
        ]

        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: keys)
        } catch {
            context.errorCount += 1
            emitProgress(url: url, context: &context, progress: progress)
            return placeholderNode(url: url, error: error.localizedDescription)
        }

        let isDirectory = values.isDirectory ?? false
        let isSymlink = values.isSymbolicLink ?? false
        if isSymlink {
            context.symlinkCount += 1
        } else if isDirectory {
            context.directoryCount += 1
        } else {
            context.fileCount += 1
        }
        let modifiedAt = values.contentModificationDate
        let createdAt = values.creationDate

        guard isDirectory, !isSymlink else {
            let logicalSize = Int64(values.fileSize ?? 0)
            let allocatedSize = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
            context.discoveredBytes += allocatedSize > 0 ? allocatedSize : logicalSize
            emitProgress(url: url, context: &context, progress: progress)
            return makeNode(
                url: url,
                isDirectory: isDirectory,
                isSymlink: isSymlink,
                logicalSize: logicalSize,
                allocatedSize: allocatedSize,
                modifiedAt: modifiedAt,
                createdAt: createdAt,
                context: &context
            )
        }

        if let issue = Self.traversalIssue(url, resolvedRootPath: context.resolvedRootPath) {
            context.errorCount += 1
            return makeNode(
                url: url, isDirectory: true, logicalSize: 0, allocatedSize: 0,
                modifiedAt: modifiedAt, createdAt: createdAt,
                scanError: issue, context: &context
            )
        }

        if options.maxRetainedChildrenPerDirectory == 0 || nodeBudget == 1 {
            return collapsedDirectoryNode(
                url,
                values: values,
                context: &context,
                progress: progress
            )
        }

        // Share the display budget between siblings, preserving a useful overview of
        // every large top-level folder. Budget-one subtrees are measured without
        // creating millions of descendant FileNodes. Counts and sizes stay complete.
        var displayOptions = options
        var childBudget: Int?
        if let nodeBudget {
            let childLimit = min(options.maxRetainedChildrenPerDirectory ?? (nodeBudget - 1), nodeBudget - 1)
            let sampledCount = immediateChildCount(url, upTo: childLimit)
            let retainedLimit = max(1, sampledCount)
            displayOptions = ScanOptions(maxRetainedChildrenPerDirectory: retainedLimit)
            childBudget = max(1, (nodeBudget - 1) / retainedLimit)
        }

        let errors = EnumeratorErrorCounter()
        let errorsBeforeChildren = context.errorCount
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsSubdirectoryDescendants],
            errorHandler: { _, _ in
                errors.count += 1
                return !Task.isCancelled
            }
        ) else {
            context.errorCount += 1
            return makeNode(
                url: url, isDirectory: true, logicalSize: 0, allocatedSize: 0,
                modifiedAt: modifiedAt, createdAt: createdAt,
                scanError: "Could not enumerate this folder.", context: &context
            )
        }

        var retainedChildren: [FileNode] = []
        var logicalSize: Int64 = 0
        var allocatedSize: Int64 = 0
        while !Task.isCancelled {
            // Drain Foundation's temporary URL/resource objects for every entry.
            let child: FileNode? = autoreleasepool {
                guard let childURL = enumerator.nextObject() as? URL else { return nil }
                return scanNode(childURL, context: &context, options: options, nodeBudget: childBudget, progress: progress)
            }
            context.errorCount += errors.transfer()
            guard let child else { break }
            logicalSize += child.logicalSize
            allocatedSize += child.allocatedSize
            retainDisplayChild(child, in: &retainedChildren, options: displayOptions)
        }
        context.errorCount += errors.transfer()
        finalizeRetainedChildren(&retainedChildren, options: displayOptions)
        emitProgress(url: url, context: &context, progress: progress)

        return makeNode(
            url: url,
            isDirectory: true,
            isSymlink: false,
            logicalSize: logicalSize,
            allocatedSize: allocatedSize,
            modifiedAt: modifiedAt,
            createdAt: createdAt,
            children: retainedChildren,
            scanError: Task.isCancelled ? "Scan cancelled" : (context.errorCount > errorsBeforeChildren ? "Some descendants could not be read." : nil),
            context: &context
        )
    }

    static func traversalIssue(_ url: URL, resolvedRootPath: String) -> String? {
        if let issue = excludedNamespaceReason(url) { return issue }
        let candidate = url.standardizedFileURL.resolvingSymlinksInPath().path
        let prefix = resolvedRootPath == "/" ? "/" : resolvedRootPath + "/"
        guard candidate == resolvedRootPath || candidate.hasPrefix(prefix) else {
            return "Folder resolves outside the selected scan root."
        }
        // A whole-drive scan reaches the canonical folder separately. Following
        // Data-volume firmlinks again duplicates counts, work, and displayed paths.
        if resolvedRootPath == "/", candidate != url.standardizedFileURL.path {
            return "Filesystem alias skipped; its canonical folder is scanned separately."
        }
        return nil
    }

    /// Kernel path-control namespaces can expose the root again without being symlinks.
    static func excludedNamespaceReason(_ url: URL) -> String? {
        let path = url.standardizedFileURL.path
        if path == "/dev" || path.hasPrefix("/dev/") {
            return "Virtual device filesystem is not disk storage and was skipped."
        }
        for namespace in ["/.nofollow", "/.resolve"] {
            if path == namespace || path.hasPrefix(namespace + "/") {
                return "Virtual filesystem path namespace skipped; use its canonical folder instead."
            }
        }
        return nil
    }

    private func immediateChildCount(_ url: URL, upTo limit: Int) -> Int {
        guard let enumerator = fileManager.enumerator(
            at: url, includingPropertiesForKeys: nil,
            options: [.skipsSubdirectoryDescendants], errorHandler: nil
        ) else { return 0 }
        var count = 0
        while count < limit, !Task.isCancelled {
            let hasNext = autoreleasepool { enumerator.nextObject() != nil }
            guard hasNext else { break }
            count += 1
        }
        return count
    }

    // Measure every entry while retaining only the candidate root.
    private func collapsedDirectoryNode(
        _ url: URL,
        values: URLResourceValues,
        context: inout ScanContext,
        progress: ProgressHandler?
    ) -> FileNode {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey
        ]
        let errors = EnumeratorErrorCounter()
        let errorsBeforeChildren = context.errorCount
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in
                errors.count += 1
                return !Task.isCancelled
            }
        ) else {
            context.errorCount += 1
            return makeNode(
                url: url,
                isDirectory: true,
                isSymlink: false,
                logicalSize: 0,
                allocatedSize: 0,
                modifiedAt: values.contentModificationDate,
                createdAt: values.creationDate,
                scanError: "Could not enumerate this folder.",
                context: &context
            )
        }

        var logicalSize: Int64 = 0
        var allocatedSize: Int64 = 0
        while !Task.isCancelled {
            let hasNext: Bool = autoreleasepool {
                guard let childURL = enumerator.nextObject() as? URL else { return false }
                context.nodeCount += 1
                context.errorCount += errors.transfer()
                if Self.excludedNamespaceReason(childURL) != nil {
                    enumerator.skipDescendants()
                    context.directoryCount += 1
                    context.errorCount += 1
                    emitProgress(url: childURL, context: &context, progress: progress)
                    return true
                }

                let childValues: URLResourceValues
                do {
                    childValues = try childURL.resourceValues(forKeys: keys)
                } catch {
                    context.errorCount += 1
                    emitProgress(url: childURL, context: &context, progress: progress)
                    return true
                }

                let isDirectory = childValues.isDirectory ?? false
                let isSymlink = childValues.isSymbolicLink ?? false
                if isSymlink {
                    context.symlinkCount += 1
                    enumerator.skipDescendants()
                } else if isDirectory {
                    context.directoryCount += 1
                    if Self.traversalIssue(childURL, resolvedRootPath: context.resolvedRootPath) != nil {
                        enumerator.skipDescendants()
                        context.errorCount += 1
                    }
                    emitProgress(url: childURL, context: &context, progress: progress)
                    return true
                } else {
                    context.fileCount += 1
                }

                let logical = Int64(childValues.fileSize ?? 0)
                let allocated = Int64(childValues.totalFileAllocatedSize ?? childValues.fileAllocatedSize ?? childValues.fileSize ?? 0)
                logicalSize += logical
                allocatedSize += allocated
                context.discoveredBytes += allocated > 0 ? allocated : logical
                emitProgress(url: childURL, context: &context, progress: progress)
                return true
            }
            guard hasNext else { break }
        }
        context.errorCount += errors.transfer()

        return makeNode(
            url: url,
            isDirectory: true,
            isSymlink: false,
            logicalSize: logicalSize,
            allocatedSize: allocatedSize,
            modifiedAt: values.contentModificationDate,
            createdAt: values.creationDate,
            scanError: Task.isCancelled ? "Scan cancelled" : (context.errorCount > errorsBeforeChildren ? "Some descendants could not be read." : nil),
            context: &context
        )
    }

    private func makeNode(
        url: URL,
        isDirectory: Bool,
        isSymlink: Bool = false,
        logicalSize: Int64,
        allocatedSize: Int64,
        modifiedAt: Date? = nil,
        createdAt: Date? = nil,
        children: [FileNode] = [],
        scanError: String? = nil,
        context: inout ScanContext
    ) -> FileNode {
        context.createdNodeCount += 1
        return FileNode(
            url: url,
            isDirectory: isDirectory,
            isSymlink: isSymlink,
            logicalSize: logicalSize,
            allocatedSize: allocatedSize,
            modifiedAt: modifiedAt,
            createdAt: createdAt,
            children: children,
            scanError: scanError
        )
    }

    private func placeholderNode(url: URL, error: String) -> FileNode {
        FileNode(
            url: url,
            isDirectory: false,
            logicalSize: 0,
            allocatedSize: 0,
            scanError: error
        )
    }

    private func emitProgress(
        url: URL,
        context: inout ScanContext,
        progress: ProgressHandler?,
        force: Bool = false
    ) {
        guard context.shouldEmitProgress(force: force) else {
            return
        }

        progress?(
            ScanProgress(
                currentPath: url.path,
                scannedCount: context.nodeCount,
                fileCount: context.fileCount,
                directoryCount: context.directoryCount,
                symlinkCount: context.symlinkCount,
                errorCount: context.errorCount,
                discoveredBytes: context.discoveredBytes,
                startedAt: context.startedAt
            )
        )
    }

    private func retainDisplayChild(
        _ child: FileNode,
        in retainedChildren: inout [FileNode],
        options: ScanOptions
    ) {
        retainedChildren.append(child)

        guard let limit = options.maxRetainedChildrenPerDirectory else {
            return
        }

        let compactionThreshold = max(limit * 2, limit + 1)
        guard retainedChildren.count > compactionThreshold else {
            return
        }

        finalizeRetainedChildren(&retainedChildren, options: options)
    }

    private func finalizeRetainedChildren(
        _ retainedChildren: inout [FileNode],
        options: ScanOptions
    ) {
        retainedChildren.sort(by: Self.displaySort)
        if let limit = options.maxRetainedChildrenPerDirectory, retainedChildren.count > limit {
            retainedChildren.removeLast(retainedChildren.count - limit)
        }
    }

    private static func displaySort(lhs: FileNode, rhs: FileNode) -> Bool {
        if lhs.effectiveSize == rhs.effectiveSize {
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
        return lhs.effectiveSize > rhs.effectiveSize
    }
}

public struct ScanOptions: Equatable, Sendable {
    public static let appDefault = ScanOptions(maxRetainedChildrenPerDirectory: 256, maxRetainedNodes: 10_000)
    public static let fullRetention = ScanOptions(maxRetainedChildrenPerDirectory: nil)
    public static let collapsed = ScanOptions(maxRetainedChildrenPerDirectory: 0)

    public let maxRetainedChildrenPerDirectory: Int?
    public let maxRetainedNodes: Int?

    public init(maxRetainedChildrenPerDirectory: Int? = 256, maxRetainedNodes: Int? = nil) {
        precondition(maxRetainedChildrenPerDirectory.map { $0 >= 0 } ?? true)
        precondition(maxRetainedNodes.map { $0 >= 1 } ?? true)
        self.maxRetainedChildrenPerDirectory = maxRetainedChildrenPerDirectory
        self.maxRetainedNodes = maxRetainedNodes
    }
}

private struct ScanContext {
    let startedAt: Date
    let resolvedRootPath: String
    var nodeCount = 0
    var fileCount = 0
    var directoryCount = 0
    var symlinkCount = 0
    var errorCount = 0
    var createdNodeCount = 0
    var discoveredBytes: Int64 = 0
    var lastProgressEmittedAt = Date.distantPast

    mutating func shouldEmitProgress(force: Bool) -> Bool {
        if force {
            lastProgressEmittedAt = Date()
            return true
        }

        // Keep progress at 10 Hz so small-file trees do not flood the main actor.
        let now = Date()
        guard now.timeIntervalSince(lastProgressEmittedAt) >= 0.1 else {
            return false
        }

        lastProgressEmittedAt = now
        return true
    }
}

private final class EnumeratorErrorCounter: @unchecked Sendable {
    var count = 0

    func transfer() -> Int {
        let value = count
        count = 0
        return value
    }
}
