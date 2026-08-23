import Foundation

protocol ActivitySourceConnector: Sendable {
    func scan(source: SourceDescriptor) async throws -> [CollectedActivity]
}
