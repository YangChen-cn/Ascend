import Foundation

struct AssessmentPackage: Codable, Sendable {
    let knowledgeNodeID: UUID
    let items: [Item]

    init(knowledgeNodeID: UUID, items: [Item]) {
        self.knowledgeNodeID = knowledgeNodeID
        self.items = items
    }

    private enum CodingKeys: String, CodingKey {
        case knowledgeNodeID
        case items
        case questions
        case assessmentItems
        case assessment_items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        knowledgeNodeID = try container.decode(UUID.self, forKey: .knowledgeNodeID)
        if let decodedItems = try? container.decode([Item].self, forKey: .items) {
            items = decodedItems
        } else if let decodedItems = try? container.decode([Item].self, forKey: .questions) {
            items = decodedItems
        } else if let decodedItems = try? container.decode([Item].self, forKey: .assessmentItems) {
            items = decodedItems
        } else if let decodedItems = try? container.decode([Item].self, forKey: .assessment_items) {
            items = decodedItems
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.items,
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "题包缺少 items/questions/assessmentItems"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(knowledgeNodeID, forKey: .knowledgeNodeID)
        try container.encode(items, forKey: .items)
    }

    struct Item: Codable, Identifiable, Sendable {
        let id: UUID
        let knowledgeNodeID: UUID
        let tier: AssessmentTier
        let stem: String
        let answerOptions: [String]
        let correctAnswerIndex: Int
        let reasoningPrompt: String
        let reasoningOptions: [String]
        let correctReasoningIndex: Int
        let explanation: String
        let misconceptionTags: [String]
        let sourceActivityIDs: [UUID]

        init(
            id: UUID = UUID(),
            knowledgeNodeID: UUID,
            tier: AssessmentTier,
            stem: String,
            answerOptions: [String],
            correctAnswerIndex: Int,
            reasoningPrompt: String,
            reasoningOptions: [String],
            correctReasoningIndex: Int,
            explanation: String,
            misconceptionTags: [String],
            sourceActivityIDs: [UUID]
        ) {
            self.id = id
            self.knowledgeNodeID = knowledgeNodeID
            self.tier = tier
            self.stem = stem
            self.answerOptions = answerOptions
            self.correctAnswerIndex = correctAnswerIndex
            self.reasoningPrompt = reasoningPrompt
            self.reasoningOptions = reasoningOptions
            self.correctReasoningIndex = correctReasoningIndex
            self.explanation = explanation
            self.misconceptionTags = misconceptionTags
            self.sourceActivityIDs = sourceActivityIDs
        }
    }
}
