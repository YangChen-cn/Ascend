import Foundation
import SwiftData

@Model
final class AssessmentItem {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var knowledgeNodeID: UUID
    var tierRawValue: String
    var stem: String
    var answerOptionsJSON: String
    var correctAnswerIndex: Int
    var reasoningPrompt: String
    var reasoningOptionsJSON: String
    var correctReasoningIndex: Int
    var explanation: String
    var misconceptionTagsJSON: String
    var sourceActivityIDsJSON: String
    var isInvalidated: Bool

    init(sessionID: UUID, item: AssessmentPackage.Item) {
        self.id = item.id
        self.sessionID = sessionID
        self.knowledgeNodeID = item.knowledgeNodeID
        self.tierRawValue = item.tier.rawValue
        self.stem = item.stem
        self.answerOptionsJSON = Self.encode(item.answerOptions)
        self.correctAnswerIndex = item.correctAnswerIndex
        self.reasoningPrompt = item.reasoningPrompt
        self.reasoningOptionsJSON = Self.encode(item.reasoningOptions)
        self.correctReasoningIndex = item.correctReasoningIndex
        self.explanation = item.explanation
        self.misconceptionTagsJSON = Self.encode(item.misconceptionTags)
        self.sourceActivityIDsJSON = Self.encode(item.sourceActivityIDs)
        self.isInvalidated = false
    }

    var tier: AssessmentTier {
        AssessmentTier(rawValue: tierRawValue) ?? .foundational
    }

    var answerOptions: [String] { Self.decode([String].self, from: answerOptionsJSON) ?? [] }
    var reasoningOptions: [String] { Self.decode([String].self, from: reasoningOptionsJSON) ?? [] }
    var misconceptionTags: [String] { Self.decode([String].self, from: misconceptionTagsJSON) ?? [] }
    var sourceActivityIDs: [UUID] { Self.decode([UUID].self, from: sourceActivityIDsJSON) ?? [] }

    private static func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        try? JSONDecoder().decode(type, from: Data(string.utf8))
    }
}
