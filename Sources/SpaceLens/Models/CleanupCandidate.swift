import Foundation

public enum CleanupAction: String, CaseIterable, Identifiable, Sendable {
    case reviewOnly
    case revealInFinder
    case queueForFutureTrash

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .reviewOnly:
            "Review Only"
        case .revealInFinder:
            "Reveal in Finder"
        case .queueForFutureTrash:
            "Queued for Future Trash"
        }
    }
}

public struct CleanupCandidate: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let fileNode: FileNode
    public let classification: SafetyClassification
    public let estimatedRecoverableBytes: Int64
    public let action: CleanupAction

    public init(
        id: UUID = UUID(),
        fileNode: FileNode,
        classification: SafetyClassification,
        estimatedRecoverableBytes: Int64,
        action: CleanupAction
    ) {
        self.id = id
        self.fileNode = fileNode
        self.classification = classification
        self.estimatedRecoverableBytes = estimatedRecoverableBytes
        self.action = action
    }
}
