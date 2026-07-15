import Darwin
import Foundation

public struct FileIdentity: Hashable, Sendable {
    public let deviceID: UInt64
    public let fileID: UInt64
    public let fileType: UInt32

    public static func capture(at url: URL) -> FileIdentity? {
        var metadata = Darwin.stat()
        guard lstat(url.path, &metadata) == 0 else {
            return nil
        }

        return FileIdentity(
            deviceID: UInt64(metadata.st_dev),
            fileID: UInt64(metadata.st_ino),
            fileType: UInt32(metadata.st_mode & mode_t(S_IFMT))
        )
    }

    public var isSymbolicLink: Bool {
        fileType == UInt32(S_IFLNK)
    }
}

public struct FileNode: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let isSymlink: Bool
    public let logicalSize: Int64
    public let allocatedSize: Int64
    public let modifiedAt: Date?
    public let createdAt: Date?
    public let fileIdentity: FileIdentity?
    public let children: [FileNode]
    public let scanError: String?

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        path: String? = nil,
        isDirectory: Bool,
        isSymlink: Bool = false,
        logicalSize: Int64,
        allocatedSize: Int64,
        modifiedAt: Date? = nil,
        createdAt: Date? = nil,
        fileIdentity: FileIdentity? = nil,
        children: [FileNode] = [],
        scanError: String? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.path = path ?? url.path
        self.isDirectory = isDirectory
        self.isSymlink = isSymlink
        self.logicalSize = logicalSize
        self.allocatedSize = allocatedSize
        self.modifiedAt = modifiedAt
        self.createdAt = createdAt
        self.fileIdentity = fileIdentity ?? FileIdentity.capture(at: url)
        self.children = children
        self.scanError = scanError
    }

    public var effectiveSize: Int64 {
        allocatedSize > 0 ? allocatedSize : logicalSize
    }

    public var displayName: String {
        name.isEmpty ? path : name
    }
}

public extension FileNode {
    func flattened(depth: Int = 0) -> [FlattenedFileNode] {
        var result: [FlattenedFileNode] = []
        appendFlattened(into: &result, depth: depth)
        return result
    }

    private func appendFlattened(into result: inout [FlattenedFileNode], depth: Int) {
        result.append(FlattenedFileNode(node: self, depth: depth))
        for child in children {
            child.appendFlattened(into: &result, depth: depth + 1)
        }
    }

    func find(id: UUID) -> FileNode? {
        if self.id == id {
            return self
        }

        for child in children {
            if let match = child.find(id: id) {
                return match
            }
        }

        return nil
    }

    func removing(id targetID: UUID) -> FileNode? {
        if id == targetID {
            return nil
        }

        let updatedChildren = children.compactMap { $0.removing(id: targetID) }
        guard updatedChildren != children else {
            return self
        }

        let logicalSize = updatedChildren.reduce(Int64(0)) { $0 + $1.logicalSize }
        let allocatedSize = updatedChildren.reduce(Int64(0)) { $0 + $1.allocatedSize }

        return FileNode(
            id: id,
            url: url,
            name: name,
            path: path,
            isDirectory: isDirectory,
            isSymlink: isSymlink,
            logicalSize: isDirectory ? logicalSize : self.logicalSize,
            allocatedSize: isDirectory ? allocatedSize : self.allocatedSize,
            modifiedAt: modifiedAt,
            createdAt: createdAt,
            fileIdentity: fileIdentity,
            children: updatedChildren,
            scanError: scanError
        )
    }
}

public struct FlattenedFileNode: Identifiable, Hashable, Sendable {
    public let node: FileNode
    public let depth: Int

    public var id: UUID {
        node.id
    }

    public var sortName: String {
        node.displayName.localizedLowercase
    }

    public var sortSize: Int64 {
        node.effectiveSize
    }

    public var sortKind: String {
        if node.isDirectory {
            return "Folder"
        }

        let fileExtension = node.url.pathExtension
        return fileExtension.isEmpty ? "File" : fileExtension.localizedUppercase
    }

    public var sortModifiedAt: TimeInterval {
        node.modifiedAt?.timeIntervalSinceReferenceDate ?? 0
    }
}
