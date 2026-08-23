import Foundation

struct AIEndpointDescriptor: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let baseURL: URL
    let selectedModelID: String
    let supportsStructuredOutputs: Bool?
}
