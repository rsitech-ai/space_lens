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
    public let retainedNodeCount: Int?

    public var hasLimitedDetails: Bool {
        retainedNodeCount.map { $0 < nodeCount } ?? false
    }

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
        errorCount: Int,
        retainedNodeCount: Int? = nil
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
        self.retainedNodeCount = retainedNodeCount
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

public enum ScanPhase: Int, Sendable, Equatable {
    case discovering
    case checkingActivity
    case classifying
    case summarizing

    public var title: String {
        switch self {
        case .discovering: "Scanning files"
        case .checkingActivity: "Checking active applications"
        case .classifying: "Checking candidate safety"
        case .summarizing: "Preparing scan results"
        }
    }
}

public struct ScanProgress: Sendable, Equatable {
    public let phase: ScanPhase
    public let processedCandidateCount: Int
    public let totalCandidateCount: Int
    public let currentPath: String
    public let scannedCount: Int
    public let fileCount: Int
    public let directoryCount: Int
    public let symlinkCount: Int
    public let errorCount: Int
    public let discoveredBytes: Int64
    public let startedAt: Date

    public init(snapshot: ScanSnapshot, phase: ScanPhase, processed: Int = 0, total: Int = 0) {
        self.init(
            currentPath: snapshot.rootPath, scannedCount: snapshot.nodeCount,
            fileCount: snapshot.fileCount, directoryCount: snapshot.directoryCount,
            symlinkCount: snapshot.symlinkCount, errorCount: snapshot.errorCount,
            discoveredBytes: snapshot.totalAllocatedSize, startedAt: snapshot.startedAt,
            phase: phase, processedCandidateCount: processed, totalCandidateCount: total
        )
    }

    public init(
        currentPath: String,
        scannedCount: Int,
        fileCount: Int = 0,
        directoryCount: Int = 0,
        symlinkCount: Int = 0,
        errorCount: Int,
        discoveredBytes: Int64 = 0,
        startedAt: Date = Date(),
        phase: ScanPhase = .discovering,
        processedCandidateCount: Int = 0,
        totalCandidateCount: Int = 0
    ) {
        self.phase = phase
        self.processedCandidateCount = processedCandidateCount
        self.totalCandidateCount = totalCandidateCount
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
