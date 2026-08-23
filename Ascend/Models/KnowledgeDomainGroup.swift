import Foundation

struct KnowledgeDomainGroup: Identifiable {
    let name: String
    let nodes: [KnowledgeNode]

    var id: String { name }
}
