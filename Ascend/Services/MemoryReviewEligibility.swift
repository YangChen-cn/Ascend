import Foundation

struct MemoryReviewEvidenceSnapshot: Sendable {
    let kind: EvidenceKind
    let confidence: Double
    let independence: Double
    let isVerified: Bool
}

enum MemoryReviewEligibility {
    static func inferredGrade(for evidence: MemoryReviewEvidenceSnapshot) -> MemoryReviewGrade? {
        guard evidence.isVerified,
              evidence.confidence >= 0.9,
              evidence.independence >= 0.9 else { return nil }
        switch evidence.kind {
        // `review` and `independentSolve` encode retrieval in their semantics.
        // Exercise/explanation remain candidates for an explicit user grade; an
        // ordinary note or commit must never silently become a successful review.
        case .review, .independentSolve:
            return .good
        case .exposure, .explanation, .exercise, .project:
            return nil
        }
    }
}
