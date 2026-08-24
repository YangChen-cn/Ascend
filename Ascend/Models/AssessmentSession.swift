import Foundation
import SwiftData

@Model
final class AssessmentSession {
    @Attribute(.unique) var id: UUID
    var knowledgeNodeID: UUID
    var kindRawValue: String
    var statusRawValue: String
    var generatorModelID: String
    var reviewPlanID: UUID?
    var assistanceModeRawValue: String
    var presentedItemIDsJSON: String
    var startedAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        knowledgeNodeID: UUID,
        kind: AssessmentKind,
        generatorModelID: String,
        reviewPlanID: UUID? = nil,
        assistanceMode: AssistanceMode = .declaredUnassisted,
        startedAt: Date = .now
    ) {
        self.id = id
        self.knowledgeNodeID = knowledgeNodeID
        self.kindRawValue = kind.rawValue
        self.statusRawValue = "active"
        self.generatorModelID = generatorModelID
        self.reviewPlanID = reviewPlanID
        self.assistanceModeRawValue = assistanceMode.rawValue
        self.presentedItemIDsJSON = "[]"
        self.startedAt = startedAt
    }

    var kind: AssessmentKind {
        AssessmentKind(rawValue: kindRawValue) ?? .baseline
    }

    var assistanceMode: AssistanceMode {
        AssistanceMode(rawValue: assistanceModeRawValue) ?? .unknown
    }

    var presentedItemIDs: [UUID] {
        get { Self.decode([UUID].self, from: presentedItemIDsJSON) ?? [] }
        set { presentedItemIDsJSON = Self.encode(newValue) }
    }

    private static func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        try? JSONDecoder().decode(type, from: Data(string.utf8))
    }
}
