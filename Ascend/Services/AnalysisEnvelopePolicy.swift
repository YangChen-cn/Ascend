import Foundation

enum AnalysisEnvelopePolicy {
    enum PolicyError: LocalizedError {
        case emptySessionSummary

        var errorDescription: String? {
            switch self {
            case .emptySessionSummary:
                "sessionSummary 不能为空"
            }
        }
    }

    static func normalized(
        _ envelope: AnalysisEnvelope,
        maximumKnowledgePointsPerActivity: Int = AppConstants.defaultMaximumKnowledgePointsPerActivity
    ) throws -> AnalysisEnvelope {
        let summary = envelope.sessionSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { throw PolicyError.emptySessionSummary }

        var countsByActivity: [UUID: Int] = [:]
        var fingerprints = Set<String>()
        let evidence = envelope.evidence.filter { item in
            let normalizedName = item.knowledgeName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !normalizedName.isEmpty else { return false }

            let fingerprint = item.activityID.uuidString + "|" + normalizedName
            guard fingerprints.insert(fingerprint).inserted else { return false }

            let currentCount = countsByActivity[item.activityID, default: 0]
            guard currentCount < maximumKnowledgePointsPerActivity.clamped(to: 1...5) else { return false }
            countsByActivity[item.activityID] = currentCount + 1
            return true
        }

        let evidenceNames = Set(evidence.map {
            $0.knowledgeName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        })
        var suggestionNames = Set<String>()
        let nodeSuggestions = envelope.nodeSuggestions.filter { suggestion in
            let normalizedName = suggestion.proposedName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return evidenceNames.contains(normalizedName) && suggestionNames.insert(normalizedName).inserted
        }

        return AnalysisEnvelope(
            sessionSummary: summary,
            evidence: evidence,
            nodeSuggestions: nodeSuggestions,
            edgeSuggestions: envelope.edgeSuggestions,
            challengeSuggestion: envelope.challengeSuggestion
        )
    }
}
