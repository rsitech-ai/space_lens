import Foundation

public enum CleanupValidationError: LocalizedError, Equatable {
    case missingScanIdentity
    case outsideAuthorizedRoot
    case targetChanged

    public var errorDescription: String? {
        switch self {
        case .missingScanIdentity:
            "The selected item could not be verified. Rescan the folder before trying again."
        case .outsideAuthorizedRoot:
            "The selected item is outside the folder authorized for cleanup."
        case .targetChanged:
            "The selected item changed after it was scanned. Rescan the folder before trying again."
        }
    }
}

public enum FileCleanupService {
    public typealias ProgressHandler = @Sendable (CleanupProgress) -> Void

    public static func moveToBin(
        node: FileNode,
        authorizedRoot: URL,
        progress: ProgressHandler? = nil
    ) async throws {
        try await Task.detached(priority: .utility) {
            let url = try validatedCleanupURL(for: node, authorizedRoot: authorizedRoot)
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

    static func validatedCleanupURL(for node: FileNode, authorizedRoot: URL) throws -> URL {
        let authorizedRoot = authorizedRoot.standardizedFileURL.resolvingSymlinksInPath()
        let candidateURL = node.url.standardizedFileURL.resolvingSymlinksInPath()
        let rootPath = authorizedRoot.path
        let descendantPrefix = rootPath == "/" ? rootPath : rootPath + "/"

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

        return node.url.standardizedFileURL
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
