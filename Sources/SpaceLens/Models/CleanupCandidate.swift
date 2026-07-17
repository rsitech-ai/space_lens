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

public enum CleanupProgressPhase: String, Sendable {
    case preparing
    case deleting
    case finished

    public var displayName: String {
        switch self {
        case .preparing:
            "Preparing"
        case .deleting:
            "Deleting"
        case .finished:
            "Finished"
        }
    }
}

public struct CleanupProgress: Equatable, Sendable {
    public let phase: CleanupProgressPhase
    public let currentPath: String
    public let completedItemCount: Int
    public let totalItemCount: Int
    public let completedBytes: Int64
    public let totalBytes: Int64

    public init(
        phase: CleanupProgressPhase,
        currentPath: String,
        completedItemCount: Int,
        totalItemCount: Int,
        completedBytes: Int64,
        totalBytes: Int64
    ) {
        self.phase = phase
        self.currentPath = currentPath
        self.completedItemCount = completedItemCount
        self.totalItemCount = totalItemCount
        self.completedBytes = completedBytes
        self.totalBytes = totalBytes
    }

    public var fractionCompleted: Double {
        guard totalItemCount > 0 else {
            return 0
        }

        return min(1, Double(completedItemCount) / Double(totalItemCount))
    }
}

enum CleanupTargetNormalizer {
    static func collapsingDescendants<Element>(
        _ elements: [Element],
        url: (Element) -> URL
    ) -> [Element] {
        let sortedElements = elements.sorted { lhs, rhs in
            let lhsPath = canonicalPath(url(lhs))
            let rhsPath = canonicalPath(url(rhs))
            let lhsDepth = lhsPath.split(separator: "/").count
            let rhsDepth = rhsPath.split(separator: "/").count
            if lhsDepth == rhsDepth {
                return lhsPath.localizedStandardCompare(rhsPath) == .orderedAscending
            }
            return lhsDepth < rhsDepth
        }

        return sortedElements.reduce(into: []) { roots, element in
            guard !roots.contains(where: {
                isSameOrDescendant(url(element), of: url($0))
            }) else {
                return
            }
            roots.append(element)
        }
    }

    static func isSameOrDescendant(_ candidate: URL, of ancestor: URL) -> Bool {
        let candidatePath = canonicalPath(candidate)
        let ancestorPath = canonicalPath(ancestor)
        guard ancestorPath != "/" else {
            return true
        }
        return candidatePath == ancestorPath || candidatePath.hasPrefix(ancestorPath + "/")
    }

    private static func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
