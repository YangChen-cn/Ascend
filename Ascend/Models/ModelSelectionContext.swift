import Foundation

struct ModelSelectionContext: Identifiable, Sendable {
    let id = UUID()
    let endpointID: UUID
    let models: [RemoteModel]
}
