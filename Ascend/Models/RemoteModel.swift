import Foundation

struct RemoteModel: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let ownedBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownedBy = "owned_by"
    }
}
