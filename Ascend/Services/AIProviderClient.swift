import Foundation

protocol AIProviderClient: Sendable {
    func listModels(endpoint: AIEndpointDescriptor, apiKey: String) async throws -> [RemoteModel]
    func test(endpoint: AIEndpointDescriptor, modelID: String, apiKey: String) async throws
    func analyze(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        activities: [CollectedActivity],
        candidateNodes: [KnowledgeCandidate],
        options: AnalysisOptions
    ) async throws -> AnalysisEnvelope
    func generateAssessment(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        request: AssessmentRequest
    ) async throws -> AssessmentPackage
}

extension AIProviderClient {
    func generateAssessment(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        request: AssessmentRequest
    ) async throws -> AssessmentPackage {
        throw AssessmentGenerationError.unsupported
    }

    func analyze(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        activities: [CollectedActivity],
        candidateNodes: [KnowledgeCandidate]
    ) async throws -> AnalysisEnvelope {
        try await analyze(
            endpoint: endpoint,
            modelID: modelID,
            apiKey: apiKey,
            activities: activities,
            candidateNodes: candidateNodes,
            options: .defaults
        )
    }
}
