import Foundation

enum AnalysisJSONSchema {
    static let value: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([
            .string("sessionSummary"),
            .string("evidence"),
            .string("nodeSuggestions"),
            .string("edgeSuggestions"),
            .string("challengeSuggestion"),
            .string("possibleNextConcepts"),
            .string("assessmentPackage")
        ]),
        "properties": .object([
            "sessionSummary": .object(["type": .string("string")]),
            "evidence": .object([
                "type": .string("array"),
                "items": evidenceItem
            ]),
            "nodeSuggestions": .object([
                "type": .string("array"),
                "items": nodeItem
            ]),
            "edgeSuggestions": .object([
                "type": .string("array"),
                "items": edgeItem
            ]),
            "challengeSuggestion": .object([
                "anyOf": .array([challengeItem, .object(["type": .string("null")])])
            ]),
            "possibleNextConcepts": .object([
                "type": .string("array"),
                "items": nextConceptItem
            ]),
            "assessmentPackage": .object([
                "anyOf": .array([embeddedAssessmentPackage, .object(["type": .string("null")])])
            ])
        ])
    ])

    private static let evidenceItem: JSONValue = objectSchema(
        required: ["id", "activityID", "knowledgeName", "matchedNodeID", "matchConfidence", "kind", "difficulty", "independence", "confidence", "coverage", "summary", "rationale"],
        properties: [
            "id": stringUUID,
            "activityID": stringUUID,
            "knowledgeName": .object(["type": .string("string")]),
            "matchedNodeID": .object(["type": .array([.string("string"), .string("null")])]),
            "matchConfidence": number,
            "kind": .object(["type": .string("string"), "enum": .array(EvidenceKind.allCases.map { .string($0.rawValue) })]),
            "difficulty": number,
            "independence": number,
            "confidence": number,
            "coverage": number,
            "summary": .object(["type": .string("string")]),
            "rationale": .object(["type": .string("string")])
        ]
    )

    private static let nodeItem: JSONValue = objectSchema(
        required: ["id", "proposedName", "domain", "confidence", "rationale"],
        properties: [
            "id": stringUUID,
            "proposedName": .object(["type": .string("string")]),
            "domain": .object(["type": .string("string")]),
            "confidence": number,
            "rationale": .object(["type": .string("string")])
        ]
    )

    private static let edgeItem: JSONValue = objectSchema(
        required: ["id", "sourceName", "targetName", "relation", "confidence", "rationale"],
        properties: [
            "id": stringUUID,
            "sourceName": .object(["type": .string("string")]),
            "targetName": .object(["type": .string("string")]),
            "relation": .object([
                "type": .string("string"),
                "enum": .array(KnowledgeRelation.allCases.map { .string($0.rawValue) })
            ]),
            "confidence": number,
            "rationale": .object(["type": .string("string")])
        ]
    )

    private static let nextConceptItem: JSONValue = objectSchema(
        required: ["id", "proposedName", "domain", "prerequisiteNames", "rationale", "confidence"],
        properties: [
            "id": stringUUID,
            "proposedName": .object(["type": .string("string")]),
            "domain": .object(["type": .string("string")]),
            "prerequisiteNames": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")])
            ]),
            "rationale": .object(["type": .string("string")]),
            "confidence": number
        ]
    )

    private static let challengeItem: JSONValue = objectSchema(
        required: ["title", "description", "estimatedMinutes", "knowledgeNames", "requirement", "rewardXP"],
        properties: [
            "title": .object(["type": .string("string")]),
            "description": .object(["type": .string("string")]),
            "estimatedMinutes": .object(["type": .string("integer")]),
            "knowledgeNames": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
            "requirement": challengeRequirementItem,
            "rewardXP": .object(["type": .string("integer")])
        ]
    )

    private static let challengeRequirementItem: JSONValue = objectSchema(
        required: ["minimumEvidenceKind", "minimumIndependence", "minimumConfidence", "minimumMastery", "requiredEvidenceCount"],
        properties: [
            "minimumEvidenceKind": .object([
                "type": .string("string"),
                "enum": .array(EvidenceKind.allCases.map { .string($0.rawValue) })
            ]),
            "minimumIndependence": number,
            "minimumConfidence": number,
            "minimumMastery": number,
            "requiredEvidenceCount": .object(["type": .string("integer")])
        ]
    )

    private static let embeddedAssessmentPackage: JSONValue = objectSchema(
        required: ["domain", "knowledgeNames", "items"],
        properties: [
            "domain": .object(["type": .string("string")]),
            "knowledgeNames": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")]),
                "minItems": .number(1),
                "maxItems": .number(5)
            ]),
            "items": .object([
                "type": .string("array"),
                "items": embeddedAssessmentItem,
                "minItems": .number(5),
                "maxItems": .number(6)
            ])
        ]
    )

    private static let embeddedAssessmentItem: JSONValue = objectSchema(
        required: [
            "id", "knowledgeName", "tier", "stem", "answerOptions", "correctAnswerIndex",
            "reasoningPrompt", "reasoningOptions", "correctReasoningIndex", "explanation",
            "misconceptionTags", "sourceActivityIDs"
        ],
        properties: [
            "id": stringUUID,
            "knowledgeName": .object(["type": .string("string")]),
            "tier": .object([
                "type": .string("string"),
                "enum": .array(AssessmentTier.allCases.map { .string($0.rawValue) })
            ]),
            "stem": .object(["type": .string("string")]),
            "answerOptions": assessmentOptionArray,
            "correctAnswerIndex": assessmentOptionIndex,
            "reasoningPrompt": .object(["type": .string("string")]),
            "reasoningOptions": assessmentOptionArray,
            "correctReasoningIndex": assessmentOptionIndex,
            "explanation": .object(["type": .string("string")]),
            "misconceptionTags": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")])
            ]),
            "sourceActivityIDs": .object([
                "type": .string("array"),
                "items": stringUUID
            ])
        ]
    )

    private static let assessmentOptionArray: JSONValue = .object([
        "type": .string("array"),
        "items": .object(["type": .string("string")]),
        "minItems": .number(4),
        "maxItems": .number(4)
    ])

    private static let assessmentOptionIndex: JSONValue = .object([
        "type": .string("integer"),
        "minimum": .number(0),
        "maximum": .number(3)
    ])

    private static let stringUUID: JSONValue = .object(["type": .string("string"), "format": .string("uuid")])
    private static let number: JSONValue = .object(["type": .string("number")])

    private static func objectSchema(required: [String], properties: [String: JSONValue]) -> JSONValue {
        .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "required": .array(required.map(JSONValue.string)),
            "properties": .object(properties)
        ])
    }
}
