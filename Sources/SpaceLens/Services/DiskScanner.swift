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
        var context = ScanContext(startedAt: startedAt)
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
        let root = scanNode(rootURL, context: &context, options: options, progress: progress)
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
                errorCount: context.errorCount
            ),
            createdNodeCount: context.createdNodeCount
        )
    }

    private func scanNode(
        _ url: URL,
        context: inout ScanContext,
        options: ScanOptions,
        progress: ProgressHandler?
    ) -> FileNode {
        if Task.isCancelled {
            return placeholderNode(url: url, error: "Scan cancelled")
        }

        context.nodeCount += 1

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
            emitProgress(url: url, context: &context, progress: progress, force: true)
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

        if options.maxRetainedChildrenPerDirectory == 0 {
            return collapsedDirectoryNode(
                url,
                values: values,
                context: &context,
                progress: progress
            )
        }

        let childURLs: [URL]
        do {
            childURLs = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: []
            )
        } catch {
            context.errorCount += 1
            emitProgress(url: url, context: &context, progress: progress, force: true)
            return makeNode(
                url: url,
                isDirectory: true,
                isSymlink: false,
                logicalSize: 0,
                allocatedSize: 0,
                modifiedAt: modifiedAt,
                createdAt: createdAt,
                scanError: error.localizedDescription,
                context: &context
            )
        }

        var retainedChildren: [FileNode] = []
        let errorsBeforeChildren = context.errorCount
        var logicalSize: Int64 = 0
        var allocatedSize: Int64 = 0
        for childURL in childURLs {
            if Task.isCancelled { break }
            let child = scanNode(childURL, context: &context, options: options, progress: progress)
            logicalSize += child.logicalSize
            allocatedSize += child.allocatedSize
            retainDisplayChild(child, in: &retainedChildren, options: options)
        }
        finalizeRetainedChildren(&retainedChildren, options: options)
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
                return true
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
        var visited = 0
        while let childURL = enumerator.nextObject() as? URL {
            if visited.isMultiple(of: 256), Task.isCancelled {
                break
            }
            visited += 1
            context.nodeCount += 1
            context.errorCount += errors.transfer()

            let childValues: URLResourceValues
            do {
                childValues = try childURL.resourceValues(forKeys: keys)
            } catch {
                context.errorCount += 1
                emitProgress(url: childURL, context: &context, progress: progress)
                continue
            }

            let isDirectory = childValues.isDirectory ?? false
            let isSymlink = childValues.isSymbolicLink ?? false
            if isSymlink {
                context.symlinkCount += 1
                enumerator.skipDescendants()
            } else if isDirectory {
                context.directoryCount += 1
                emitProgress(url: childURL, context: &context, progress: progress)
                continue
            } else {
                context.fileCount += 1
            }

            let logical = Int64(childValues.fileSize ?? 0)
            let allocated = Int64(childValues.totalFileAllocatedSize ?? childValues.fileAllocatedSize ?? childValues.fileSize ?? 0)
            logicalSize += logical
            allocatedSize += allocated
            context.discoveredBytes += allocated > 0 ? allocated : logical
            emitProgress(url: childURL, context: &context, progress: progress)
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
    public static let appDefault = ScanOptions(maxRetainedChildrenPerDirectory: 256)
    public static let fullRetention = ScanOptions(maxRetainedChildrenPerDirectory: nil)
    public static let collapsed = ScanOptions(maxRetainedChildrenPerDirectory: 0)

    public let maxRetainedChildrenPerDirectory: Int?

    public init(maxRetainedChildrenPerDirectory: Int? = 256) {
        precondition(maxRetainedChildrenPerDirectory.map { $0 >= 0 } ?? true)
        self.maxRetainedChildrenPerDirectory = maxRetainedChildrenPerDirectory
    }
}

private struct ScanContext {
    let startedAt: Date
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
