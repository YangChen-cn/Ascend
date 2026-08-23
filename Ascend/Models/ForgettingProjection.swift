import Foundation

struct ForgettingProjection: Identifiable {
    let node: KnowledgeNode
    let scoreLoss: Int
    let retention: Double

    var id: UUID { node.id }
}
