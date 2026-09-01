import Foundation

enum ChallengeEvidenceReviewJSONSchema {
    static let value: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([.string("passed"), .string("confidence"), .string("summary"), .string("failureReasons")]),
        "properties": .object([
            "passed": .object(["type": .string("boolean")]),
            "confidence": .object(["type": .string("number"), "minimum": .number(0), "maximum": .number(1)]),
            "summary": .object(["type": .string("string")]),
            "failureReasons": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")])
            ])
        ])
    ])
}
