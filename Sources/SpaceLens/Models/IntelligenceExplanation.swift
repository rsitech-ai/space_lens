import Foundation

public struct IntelligenceExplanation: Hashable, Sendable {
    public let title: String
    public let body: String
    public let safetyAnswer: String
    public let nextStep: String

    public init(title: String, body: String, safetyAnswer: String, nextStep: String) {
        self.title = title
        self.body = body
        self.safetyAnswer = safetyAnswer
        self.nextStep = nextStep
    }
}

public struct ScanIntelligenceSummary: Hashable, Sendable {
    public let title: String
    public let body: String
    public let nextStep: String
    public let confidence: Double
    public let recoverableBytes: Int64
    public let theoreticalRecoverableBytes: Int64
    public let reviewCount: Int
    public let protectedCount: Int
    public let volumeHeadline: String?
    public let immediatelyAvailableBytes: Int64?
    public let auditNote: String
    public let processCaveats: [String]

    public init(
        title: String,
        body: String,
        nextStep: String,
        confidence: Double,
        recoverableBytes: Int64,
        theoreticalRecoverableBytes: Int64? = nil,
        reviewCount: Int,
        protectedCount: Int,
        volumeHeadline: String? = nil,
        immediatelyAvailableBytes: Int64? = nil,
        auditNote: String = "No files were removed.",
        processCaveats: [String] = []
    ) {
        self.title = title
        self.body = body
        self.nextStep = nextStep
        self.confidence = min(max(confidence, 0), 1)
        self.recoverableBytes = recoverableBytes
        self.theoreticalRecoverableBytes = theoreticalRecoverableBytes ?? recoverableBytes
        self.reviewCount = reviewCount
        self.protectedCount = protectedCount
        self.volumeHeadline = volumeHeadline
        self.immediatelyAvailableBytes = immediatelyAvailableBytes
        self.auditNote = auditNote
        self.processCaveats = processCaveats
    }
}
