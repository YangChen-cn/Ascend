import Foundation

struct EndpointDraft: Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var baseURLString: String
    var apiKey: String
    var selectedModelID: String
    var cachedModelIDs: [String]
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String = "新接口",
        baseURLString: String = "https://api.openai.com/v1",
        apiKey: String = "",
        selectedModelID: String = "",
        cachedModelIDs: [String] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.baseURLString = baseURLString
        self.apiKey = apiKey
        self.selectedModelID = selectedModelID
        self.cachedModelIDs = cachedModelIDs
        self.isEnabled = isEnabled
    }
}
