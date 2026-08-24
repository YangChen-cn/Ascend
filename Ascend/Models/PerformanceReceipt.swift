import Foundation
import SwiftData

@Model
final class PerformanceReceipt {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var knowledgeNodeID: UUID
    var contextHash: String
    var verificationLevelRawValue: String
    var assistanceModeRawValue: String
    var score: Double
    var scoringConfidence: Double = 1
    var occurredAt: Date
    var summary: String

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        knowledgeNodeID: UUID,
        contextHash: String,
        verificationLevel: VerificationLevel,
        assistanceMode: AssistanceMode,
        score: Double,
        scoringConfidence: Double = 1,
        occurredAt: Date = .now,
        summary: String
    ) {
        self.id = id
        self.sessionID = sessionID
        self.knowledgeNodeID = knowledgeNodeID
        self.contextHash = contextHash
        self.verificationLevelRawValue = verificationLevel.rawValue
        self.assistanceModeRawValue = assistanceMode.rawValue
        self.score = score.clamped(to: 0...1)
        self.scoringConfidence = scoringConfidence.clamped(to: 0...1)
        self.occurredAt = occurredAt
        self.summary = summary
    }

    var verificationLevel: VerificationLevel {
        VerificationLevel(rawValue: verificationLevelRawValue) ?? .productionRubric
    }

    var assistanceMode: AssistanceMode {
        AssistanceMode(rawValue: assistanceModeRawValue) ?? .unknown
    }

    var passed: Bool {
        score >= 0.7
    }

    var timestampText: String {
        occurredAt.formatted(.dateTime.month().day().year())
    }
}
