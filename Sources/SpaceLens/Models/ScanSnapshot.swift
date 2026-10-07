import Foundation

public struct ScanSnapshot: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let rootPath: String
    public let startedAt: Date
    public let completedAt: Date
    public let totalLogicalSize: Int64
    public let totalAllocatedSize: Int64
    public let nodeCount: Int
    public let fileCount: Int
    public let directoryCount: Int
    public let symlinkCount: Int
    public let errorCount: Int

    public init(
        id: UUID = UUID(),
        rootPath: String,
        startedAt: Date,
        completedAt: Date,
        totalLogicalSize: Int64,
        totalAllocatedSize: Int64,
        nodeCount: Int,
        fileCount: Int = 0,
        directoryCount: Int = 0,
        symlinkCount: Int = 0,
        errorCount: Int
    ) {
        self.id = id
        self.rootPath = rootPath
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.totalLogicalSize = totalLogicalSize
        self.totalAllocatedSize = totalAllocatedSize
        self.nodeCount = nodeCount
        self.fileCount = fileCount
        self.directoryCount = directoryCount
        self.symlinkCount = symlinkCount
        self.errorCount = errorCount
    }
}

public struct ScanResult: Sendable {
    public let root: FileNode
    public let snapshot: ScanSnapshot
    public let pendingDiscoveryPaths: [String]
    public let simulatorInventory: SimulatorInventory
    public let createdNodeCount: Int

    public init(
        root: FileNode,
        snapshot: ScanSnapshot,
        pendingDiscoveryPaths: [String] = [],
        simulatorInventory: SimulatorInventory = .empty,
        createdNodeCount: Int = 0
    ) {
        self.root = root
        self.snapshot = snapshot
        self.pendingDiscoveryPaths = pendingDiscoveryPaths
        self.simulatorInventory = simulatorInventory
        self.createdNodeCount = createdNodeCount
    }
}

public struct ScanProgress: Sendable, Equatable {
    public let currentPath: String
    public let scannedCount: Int
    public let fileCount: Int
    public let directoryCount: Int
    public let symlinkCount: Int
    public let errorCount: Int
    public let discoveredBytes: Int64
    public let startedAt: Date

    public init(
        currentPath: String,
        scannedCount: Int,
        fileCount: Int = 0,
        directoryCount: Int = 0,
        symlinkCount: Int = 0,
        errorCount: Int,
        discoveredBytes: Int64 = 0,
        startedAt: Date = Date()
    ) {
        self.currentPath = currentPath
        self.scannedCount = scannedCount
        self.fileCount = fileCount
        self.directoryCount = directoryCount
        self.symlinkCount = symlinkCount
        self.errorCount = errorCount
        self.discoveredBytes = discoveredBytes
        self.startedAt = startedAt
    }
}
