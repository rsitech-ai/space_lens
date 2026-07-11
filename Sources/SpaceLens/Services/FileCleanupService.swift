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
