import Foundation
import SwiftData

@Model
final class ChallengeAutomationState {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var challengeID: UUID
    var requirementJSON: String
    var acceptedAt: Date?
    var completedAt: Date?
    var matchedEvidenceIDsJSON: String

    init(
        id: UUID = UUID(),
        challengeID: UUID,
        requirement: ChallengeRequirement,
        acceptedAt: Date? = nil,
        completedAt: Date? = nil,
        matchedEvidenceIDs: [UUID] = []
    ) {
        self.id = id
        self.challengeID = challengeID
        self.requirementJSON = Self.encode(requirement)
        self.acceptedAt = acceptedAt
        self.completedAt = completedAt
        self.matchedEvidenceIDsJSON = Self.encode(matchedEvidenceIDs)
    }

    var requirement: ChallengeRequirement {
        Self.decode(ChallengeRequirement.self, from: requirementJSON) ?? ChallengeRequirement()
    }

    var matchedEvidenceIDs: [UUID] {
        get { Self.decode([UUID].self, from: matchedEvidenceIDsJSON) ?? [] }
        set { matchedEvidenceIDsJSON = Self.encode(newValue) }
    }

    private static func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        try? JSONDecoder().decode(type, from: Data(string.utf8))
    }
}
