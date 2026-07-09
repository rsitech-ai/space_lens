import Foundation

public enum FileCleanupService {
    public typealias ProgressHandler = @Sendable (CleanupProgress) -> Void

    public static func moveToBin(url: URL, progress: ProgressHandler? = nil) async throws {
        try await Task.detached(priority: .utility) {
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
        }.value
    }

    public static func deleteForever(url: URL, progress: ProgressHandler? = nil) async throws {
        try await Task.detached(priority: .utility) {
            let summary = try deletionSummary(for: url)
            progress?(
                CleanupProgress(
                    phase: .preparing,
                    currentPath: url.path,
                    completedItemCount: 0,
                    totalItemCount: summary.itemCount,
                    completedBytes: 0,
                    totalBytes: summary.allocatedBytes
                )
            )

            var state = DeletionState()
            try deleteRecursively(
                url,
                total: summary,
                state: &state,
                progress: progress
            )

            progress?(
                CleanupProgress(
                    phase: .finished,
                    currentPath: url.path,
                    completedItemCount: summary.itemCount,
                    totalItemCount: summary.itemCount,
                    completedBytes: summary.allocatedBytes,
                    totalBytes: summary.allocatedBytes
                )
            )
        }.value
    }

    private static func deletionSummary(for url: URL) throws -> DeletionSummary {
        var summary = DeletionSummary()
        try accumulateDeletionSummary(for: url, into: &summary)
        return summary
    }

    private static func accumulateDeletionSummary(for url: URL, into summary: inout DeletionSummary) throws {
        summary.itemCount += 1
        summary.allocatedBytes += allocatedSize(of: url)

        guard isDirectory(url), !isSymbolicLink(url) else {
            return
        }

        let children = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: deletionResourceKeys,
            options: []
        )

        for child in children {
            try accumulateDeletionSummary(for: child, into: &summary)
        }
    }

    private static func deleteRecursively(
        _ url: URL,
        total: DeletionSummary,
        state: inout DeletionState,
        progress: ProgressHandler?
    ) throws {
        let bytes = allocatedSize(of: url)

        if isDirectory(url), !isSymbolicLink(url) {
            let children = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: deletionResourceKeys,
                options: []
            )

            for child in children {
                try deleteRecursively(child, total: total, state: &state, progress: progress)
            }
        }

        try FileManager.default.removeItem(at: url)
        state.deletedItemCount += 1
        state.deletedBytes += bytes

        progress?(
            CleanupProgress(
                phase: .deleting,
                currentPath: url.path,
                completedItemCount: state.deletedItemCount,
                totalItemCount: total.itemCount,
                completedBytes: state.deletedBytes,
                totalBytes: total.allocatedBytes
            )
        )
    }

    private static var deletionResourceKeys: [URLResourceKey] {
        [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
            .fileSizeKey
        ]
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
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

private struct DeletionSummary: Sendable {
    var itemCount = 0
    var allocatedBytes: Int64 = 0
}

private struct DeletionState: Sendable {
    var deletedItemCount = 0
    var deletedBytes: Int64 = 0
}
