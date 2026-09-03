import Foundation

/// 一次挑战实作候选材料的最小 AI 审核输入。所有来源片段均是数据，不是指令。
struct ChallengeEvidenceReviewRequest: Codable, Sendable {
    struct Target: Codable, Sendable {
        let id: UUID
        let name: String
    }

    struct Source: Codable, Sendable {
        let title: String
        let locator: String
        let contentHash: String
        let occurredAt: Date
        let selectedFilePaths: [String]
        let auditExcerpt: String

        init(
            title: String,
            locator: String,
            contentHash: String,
            occurredAt: Date,
            selectedFilePaths: [String] = [],
            auditExcerpt: String
        ) {
            self.title = title
            self.locator = locator
            self.contentHash = contentHash
            self.occurredAt = occurredAt
            self.selectedFilePaths = selectedFilePaths
            self.auditExcerpt = auditExcerpt
        }
    }

    let challengeTitle: String
    let challengeDescription: String
    let requirements: [String]
    let targets: [Target]
    let source: Source
    let declarations: [String]
    let userDetail: String
    let priorFailureReasons: [String]
}

struct ChallengeEvidenceReview: Codable, Sendable, Equatable {
    let passed: Bool
    let confidence: Double
    let summary: String
    let failureReasons: [String]
}

enum ChallengeEvidenceReviewPolicy: Sendable {
    static let minimumConfidence = 0.8

    static func normalized(_ review: ChallengeEvidenceReview) -> ChallengeEvidenceReview {
        let reasons = review.failureReasons
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return ChallengeEvidenceReview(
            passed: review.passed,
            confidence: min(1, max(0, review.confidence)),
            summary: review.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            failureReasons: review.passed ? reasons : (reasons.isEmpty ? ["材料不足以证明已完成挑战要求。"] : reasons)
        )
    }

    static func isPassing(_ review: ChallengeEvidenceReview) -> Bool {
        review.passed && normalized(review).confidence >= minimumConfidence
    }
}

enum ChallengeEvidenceReviewError: LocalizedError {
    case unsupported

    var errorDescription: String? {
        switch self {
        case .unsupported: "当前 AI 接口不支持挑战实作核验"
        }
    }
}
