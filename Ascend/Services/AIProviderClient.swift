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
    func generateAssessmentBatch(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        requests: [AssessmentRequest]
    ) async throws -> [AssessmentPackage]
    func reviewChallengeEvidence(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        request: ChallengeEvidenceReviewRequest
    ) async throws -> ChallengeEvidenceReview
    func setCapabilityUpdateHandler(_ handler: (@Sendable (UUID, Bool) async -> Void)?) async
}

extension AIProviderClient {
    func setCapabilityUpdateHandler(_ handler: (@Sendable (UUID, Bool) async -> Void)?) async {}
    func generateAssessment(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        request: AssessmentRequest
    ) async throws -> AssessmentPackage {
        throw AssessmentGenerationError.unsupported
    }

    func generateAssessmentBatch(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        requests: [AssessmentRequest]
    ) async throws -> [AssessmentPackage] {
        var packages: [AssessmentPackage] = []
        for request in requests {
            packages.append(
                try await generateAssessment(
                    endpoint: endpoint,
                    modelID: modelID,
                    apiKey: apiKey,
                    request: request
                )
            )
        }
        return packages
    }

    func reviewChallengeEvidence(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        request: ChallengeEvidenceReviewRequest
    ) async throws -> ChallengeEvidenceReview {
        throw ChallengeEvidenceReviewError.unsupported
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
