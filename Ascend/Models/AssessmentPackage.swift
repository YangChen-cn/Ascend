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
        if container.contains(.items) {
            items = try container.decode([Item].self, forKey: .items)
            return
        }
        if container.contains(.questions) {
            items = try container.decode([Item].self, forKey: .questions)
            return
        }
        if container.contains(.assessmentItems) {
            items = try container.decode([Item].self, forKey: .assessmentItems)
            return
        }
        if container.contains(.assessment_items) {
            items = try container.decode([Item].self, forKey: .assessment_items)
            return
        }
        throw DecodingError.keyNotFound(
            CodingKeys.items,
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "题包缺少 items/questions/assessmentItems"
            )
        )
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

        private enum CodingKeys: String, CodingKey {
            case id
            case knowledgeNodeID
            case tier
            case stem
            case answerOptions
            case correctAnswerIndex
            case reasoningPrompt
            case reasoningOptions
            case correctReasoningIndex
            case explanation
            case misconceptionTags
            case sourceActivityIDs
        }

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

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // Item IDs are local audit identities. Never reject an otherwise
            // valid AI item because a provider omitted or malformed this UUID.
            id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
            knowledgeNodeID = try container.decode(UUID.self, forKey: .knowledgeNodeID)
            tier = try container.decode(AssessmentTier.self, forKey: .tier)
            stem = try container.decode(String.self, forKey: .stem)
            answerOptions = try container.decode([String].self, forKey: .answerOptions)
            correctAnswerIndex = try container.decode(Int.self, forKey: .correctAnswerIndex)
            reasoningPrompt = try container.decode(String.self, forKey: .reasoningPrompt)
            reasoningOptions = try container.decode([String].self, forKey: .reasoningOptions)
            correctReasoningIndex = try container.decode(Int.self, forKey: .correctReasoningIndex)
            explanation = try container.decode(String.self, forKey: .explanation)
            misconceptionTags = (try? container.decode([String].self, forKey: .misconceptionTags)) ?? []
            sourceActivityIDs = (try? container.decode([UUID].self, forKey: .sourceActivityIDs)) ?? []
        }
    }
}
