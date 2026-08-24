import Foundation

enum AssessmentBatchJSONSchema {
    static let value: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([.string("packages")]),
        "properties": .object([
            "packages": .object([
                "type": .string("array"),
                "items": AssessmentJSONSchema.packageSchema(minimumItemCount: 5, maximumItemCount: 6),
                "minItems": .number(1),
                "maxItems": .number(2)
            ])
        ])
    ])
}
