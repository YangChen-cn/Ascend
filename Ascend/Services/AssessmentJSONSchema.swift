import Foundation

enum AssessmentJSONSchema {
    static let value: JSONValue = packageSchema(minimumItemCount: 5, maximumItemCount: 6)

    static func packageSchema(minimumItemCount: Int, maximumItemCount: Int) -> JSONValue {
        .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "required": .array([.string("knowledgeNodeID"), .string("items")]),
            "properties": .object([
                "knowledgeNodeID": stringUUID,
                "items": .object([
                    "type": .string("array"),
                    "items": itemSchema,
                    "minItems": .number(Double(minimumItemCount)),
                    "maxItems": .number(Double(maximumItemCount))
                ])
            ])
        ])
    }

    private static let itemSchema: JSONValue = objectSchema(
        required: [
            "id", "knowledgeNodeID", "tier", "stem", "answerOptions", "correctAnswerIndex",
            "reasoningPrompt", "reasoningOptions", "correctReasoningIndex",
            "explanation", "misconceptionTags", "sourceActivityIDs"
        ],
        properties: [
            "id": stringUUID,
            "knowledgeNodeID": stringUUID,
            "tier": .object([
                "type": .string("string"),
                "enum": .array(AssessmentTier.allCases.map { .string($0.rawValue) })
            ]),
            "stem": string,
            "answerOptions": optionArray,
            "correctAnswerIndex": integer,
            "reasoningPrompt": string,
            "reasoningOptions": optionArray,
            "correctReasoningIndex": integer,
            "explanation": string,
            "misconceptionTags": stringArray,
            "sourceActivityIDs": .object([
                "type": .string("array"),
                "items": stringUUID
            ])
        ]
    )

    private static let stringUUID: JSONValue = .object(["type": .string("string"), "format": .string("uuid")])
    private static let string: JSONValue = .object(["type": .string("string")])
    private static let integer: JSONValue = .object([
        "type": .string("integer"),
        "minimum": .number(0),
        "maximum": .number(3)
    ])
    private static let stringArray: JSONValue = .object([
        "type": .string("array"),
        "items": string
    ])
    private static let optionArray: JSONValue = .object([
        "type": .string("array"),
        "items": string,
        "minItems": .number(4),
        "maxItems": .number(4)
    ])

    private static func objectSchema(required: [String], properties: [String: JSONValue]) -> JSONValue {
        .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "required": .array(required.map(JSONValue.string)),
            "properties": .object(properties)
        ])
    }
}
