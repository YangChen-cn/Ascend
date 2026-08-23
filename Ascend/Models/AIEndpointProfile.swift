import Foundation
import SwiftData

@Model
final class AIEndpointProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var baseURLString: String
    var selectedModelID: String
    var cachedModelsJSON: String
    var isEnabled: Bool
    var supportsStructuredOutputs: Bool?
    var lastConnectedAt: Date?
    var lastError: String?

    init(
        id: UUID = UUID(),
        name: String,
        baseURLString: String,
        selectedModelID: String = "",
        cachedModelsJSON: String = "[]",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.baseURLString = baseURLString
        self.selectedModelID = selectedModelID
        self.cachedModelsJSON = cachedModelsJSON
        self.isEnabled = isEnabled
    }

    var cachedModelIDs: [String] {
        guard let data = cachedModelsJSON.data(using: .utf8),
              let models = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return models
    }

    func setCachedModelIDs(_ models: [String]) {
        cachedModelsJSON = String(
            data: (try? JSONEncoder().encode(models)) ?? Data("[]".utf8),
            encoding: .utf8
        ) ?? "[]"
    }
}
