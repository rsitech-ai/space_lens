import Foundation

public enum ScanKind: String, CaseIterable, Identifiable, Sendable {
    case rebuildableCache
    case packageCache
    case toolchain
    case docker
    case simulator
    case temp
    case userHistory
    case researchData
    case unknownLarge

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .rebuildableCache:
            "Rebuildable cache"
        case .packageCache:
            "Package cache"
        case .toolchain:
            "Toolchain"
        case .docker:
            "Docker"
        case .simulator:
            "Simulator"
        case .temp:
            "Temporary files"
        case .userHistory:
            "User history"
        case .researchData:
            "Research data"
        case .unknownLarge:
            "Unknown large"
        }
    }

    public var countsTowardTheoreticalRecovery: Bool {
        switch self {
        case .rebuildableCache, .packageCache, .temp:
            true
        case .toolchain, .docker, .simulator, .userHistory, .researchData, .unknownLarge:
            false
        }
    }
}

public enum SafetyLevel: String, CaseIterable, Identifiable, Sendable {
    case safeTemp
    case rebuildableCache
    case generatedOutput
    case largeButValuable
    case activeOrInUse
    case systemCritical
    case unknownReview

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .safeTemp:
            "Safe Temp"
        case .rebuildableCache:
            "Rebuildable Cache"
        case .generatedOutput:
            "Generated Output"
        case .largeButValuable:
            "Large But Valuable"
        case .activeOrInUse:
            "Active / Tool-Owned"
        case .systemCritical:
            "System Critical"
        case .unknownReview:
            "Review"
        }
    }

    public var isQueueable: Bool {
        switch self {
        case .safeTemp, .rebuildableCache, .generatedOutput:
            true
        case .largeButValuable, .activeOrInUse, .systemCritical, .unknownReview:
            false
        }
    }
}

public struct SafetyClassification: Hashable, Sendable {
    public let level: SafetyLevel
    public let confidence: Double
    public let category: String
    public let summary: String
    public let evidence: [String]
    public let recommendedAction: String
    public let kind: ScanKind

    public init(
        level: SafetyLevel,
        confidence: Double,
        category: String,
        summary: String,
        evidence: [String],
        recommendedAction: String,
        kind: ScanKind = .unknownLarge
    ) {
        self.level = level
        self.confidence = min(max(confidence, 0), 1)
        self.category = category
        self.summary = summary
        self.evidence = evidence
        self.recommendedAction = recommendedAction
        self.kind = kind
    }
}
