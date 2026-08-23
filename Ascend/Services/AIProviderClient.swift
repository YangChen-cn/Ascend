import Foundation

protocol AIProviderClient: Sendable {
    func listModels(endpoint: AIEndpointDescriptor, apiKey: String) async throws -> [RemoteModel]
    func test(endpoint: AIEndpointDescriptor, modelID: String, apiKey: String) async throws
    func analyze(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        activities: [CollectedActivity],
        candidateNodes: [KnowledgeCandidate]
    ) async throws -> AnalysisEnvelope
}
