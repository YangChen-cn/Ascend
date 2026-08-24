import Foundation

struct AssessmentBatchRequest: Codable, Sendable {
    let requests: [AssessmentRequest]
}
