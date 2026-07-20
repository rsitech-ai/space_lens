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
    public let reviewCount: Int
    public let protectedCount: Int

    public init(
        title: String,
        body: String,
        nextStep: String,
        confidence: Double,
        recoverableBytes: Int64,
        reviewCount: Int,
        protectedCount: Int
    ) {
        self.title = title
        self.body = body
        self.nextStep = nextStep
        self.confidence = min(max(confidence, 0), 1)
        self.recoverableBytes = recoverableBytes
        self.reviewCount = reviewCount
        self.protectedCount = protectedCount
    }
}
