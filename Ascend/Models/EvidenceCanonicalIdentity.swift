import Foundation

enum EvidenceCanonicalIdentity {
    static func key(
        contentChangeHash: String?,
        knowledgeNodeID: UUID,
        fingerprint: String,
        evidenceID: UUID
    ) -> String {
        if let contentChangeHash, !contentChangeHash.isEmpty {
            return "content:\(contentChangeHash):\(knowledgeNodeID.uuidString)"
        }
        if !fingerprint.isEmpty {
            return "event:\(fingerprint):\(knowledgeNodeID.uuidString)"
        }
        return "evidence:\(evidenceID.uuidString)"
    }
}
