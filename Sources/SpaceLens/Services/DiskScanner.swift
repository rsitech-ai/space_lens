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
        let startedAt = Date()
        var context = ScanContext(startedAt: startedAt)
        let rootURL = rootURL.standardizedFileURL
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
            )
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
            let allocatedSize = Int64(values.fileAllocatedSize ?? values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            context.discoveredBytes += allocatedSize > 0 ? allocatedSize : logicalSize
            emitProgress(url: url, context: &context, progress: progress)

            return FileNode(
                url: url,
                isDirectory: isDirectory,
                isSymlink: isSymlink,
                logicalSize: logicalSize,
                allocatedSize: allocatedSize,
                modifiedAt: modifiedAt,
                createdAt: createdAt
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
            return FileNode(
                url: url,
                isDirectory: true,
                isSymlink: false,
                logicalSize: 0,
                allocatedSize: 0,
                modifiedAt: modifiedAt,
                createdAt: createdAt,
                scanError: error.localizedDescription
            )
        }

        var retainedChildren: [FileNode] = []
        var logicalSize: Int64 = 0
        var allocatedSize: Int64 = 0
        for childURL in childURLs {
            let child = scanNode(childURL, context: &context, options: options, progress: progress)
            logicalSize += child.logicalSize
            allocatedSize += child.allocatedSize
            retainDisplayChild(child, in: &retainedChildren, options: options)
        }
        finalizeRetainedChildren(&retainedChildren, options: options)
        emitProgress(url: url, context: &context, progress: progress)

        return FileNode(
            url: url,
            isDirectory: true,
            isSymlink: false,
            logicalSize: logicalSize,
            allocatedSize: allocatedSize,
            modifiedAt: modifiedAt,
            createdAt: createdAt,
            children: retainedChildren
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
        if limit == 0 {
            retainedChildren.removeAll(keepingCapacity: true)
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
    var discoveredBytes: Int64 = 0
    var lastProgressEmittedAt = Date.distantPast
    var lastProgressNodeCount = 0

    mutating func shouldEmitProgress(force: Bool) -> Bool {
        if force {
            lastProgressEmittedAt = Date()
            lastProgressNodeCount = nodeCount
            return true
        }

        let now = Date()
        let enoughItems = nodeCount - lastProgressNodeCount >= 512
        let enoughTime = now.timeIntervalSince(lastProgressEmittedAt) >= 0.12
        guard enoughItems || enoughTime else {
            return false
        }

        lastProgressEmittedAt = now
        lastProgressNodeCount = nodeCount
        return true
    }
}
