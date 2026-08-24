import Foundation
import SwiftData

@Model
final class EvidenceRecord {
    @Attribute(.unique) var id: UUID
    var activityID: UUID
    var knowledgeNodeID: UUID
    var kindRawValue: String
    var timestamp: Date
    var summary: String
    var rationale: String
    var difficulty: Double
    var independence: Double
    var aiConfidence: Double
    var isVerified: Bool
    var fingerprint: String
    var contentChangeHash: String?
    var originRawValue: String = EvidenceOrigin.legacy.rawValue
    var verificationLevelRawValue: String = VerificationLevel.artifactCandidate.rawValue
    var assistanceModeRawValue: String = AssistanceMode.unknown.rawValue
    var assessmentSessionID: UUID?

    init(
        id: UUID = UUID(),
        activityID: UUID,
        knowledgeNodeID: UUID,
        kind: EvidenceKind,
        timestamp: Date,
        summary: String,
        rationale: String,
        difficulty: Double,
        independence: Double,
        aiConfidence: Double,
        isVerified: Bool,
        fingerprint: String,
        contentChangeHash: String? = nil,
        origin: EvidenceOrigin = .legacy,
        verificationLevel: VerificationLevel = .artifactCandidate,
        assistanceMode: AssistanceMode = .unknown,
        assessmentSessionID: UUID? = nil
    ) {
        self.id = id
        self.activityID = activityID
        self.knowledgeNodeID = knowledgeNodeID
        self.kindRawValue = kind.rawValue
        self.timestamp = timestamp
        self.summary = summary
        self.rationale = rationale
        self.difficulty = difficulty
        self.independence = independence
        self.aiConfidence = aiConfidence
        self.isVerified = isVerified
        self.fingerprint = fingerprint
        self.contentChangeHash = contentChangeHash
        self.originRawValue = origin.rawValue
        self.verificationLevelRawValue = verificationLevel.rawValue
        self.assistanceModeRawValue = assistanceMode.rawValue
        self.assessmentSessionID = assessmentSessionID
    }

    var kind: EvidenceKind {
        EvidenceKind(rawValue: kindRawValue) ?? .exposure
    }

    var origin: EvidenceOrigin {
        EvidenceOrigin(rawValue: originRawValue) ?? .legacy
    }

    var verificationLevel: VerificationLevel {
        VerificationLevel(rawValue: verificationLevelRawValue) ?? .artifactCandidate
    }

    var assistanceMode: AssistanceMode {
        AssistanceMode(rawValue: assistanceModeRawValue) ?? .unknown
    }
}
