import Foundation

struct ExportedEndpoint: Codable, Sendable {
    let id: UUID
    let name: String
    let baseURLString: String
    let selectedModelID: String
    let cachedModelIDs: [String]
    let isEnabled: Bool
}
