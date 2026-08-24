import Foundation

enum KnowledgeCandidateSelector {
    static let defaultCandidateLimit = 30
    static let minimumCandidateLimit = 20
    static let maximumCandidateLimit = 40

    static func selectCandidates(
        for activities: [CollectedActivity],
        from allNodes: [KnowledgeNode],
        relations: [KnowledgeEdge] = [],
        limit: Int = defaultCandidateLimit,
        masteryProvider: (UUID) -> Double
    ) -> [KnowledgeCandidate] {
        let effectiveLimit = min(maximumCandidateLimit, max(minimumCandidateLimit, limit))
        guard allNodes.count > effectiveLimit else {
            return allNodes.map { node in
                KnowledgeCandidate(
                    id: node.id,
                    name: node.name,
                    domain: node.domain,
                    mastery: masteryProvider(node.id)
                )
            }
        }

        let activityText = activities.map {
            "\($0.title) \($0.summary) \($0.excerpt) \($0.sourceLocator)"
        }.joined(separator: "\n").lowercased()

        let activityTokens = tokenize(activityText)

        var directScores: [UUID: Double] = [:]
        for node in allNodes {
            var score = 0.0
            let normalizedName = node.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedDomain = node.domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            if !normalizedName.isEmpty, activityText.contains(normalizedName) {
                score += 15.0
            }

            let nameTokens = tokenize(normalizedName)
            let overlapCount = nameTokens.intersection(activityTokens).count
            if overlapCount > 0 {
                score += Double(overlapCount) * 5.0
            }

            if !normalizedDomain.isEmpty, activityText.contains(normalizedDomain) {
                score += 4.0
            }

            let domainTokens = tokenize(normalizedDomain)
            let domainOverlap = domainTokens.intersection(activityTokens).count
            if domainOverlap > 0 {
                score += Double(domainOverlap) * 2.0
            }

            directScores[node.id] = score
        }

        var totalScores = directScores
        for relation in relations {
            let sourceScore = directScores[relation.sourceNodeID, default: 0]
            let targetScore = directScores[relation.targetNodeID, default: 0]
            if sourceScore > 0 {
                totalScores[relation.targetNodeID, default: 0] += 2.0
            }
            if targetScore > 0 {
                totalScores[relation.sourceNodeID, default: 0] += 2.0
            }
        }

        let sortedNodes = allNodes.sorted { lhs, rhs in
            let lhsScore = totalScores[lhs.id, default: 0]
            let rhsScore = totalScores[rhs.id, default: 0]
            if abs(lhsScore - rhsScore) > 0.001 {
                return lhsScore > rhsScore
            }
            let lhsMastery = masteryProvider(lhs.id)
            let rhsMastery = masteryProvider(rhs.id)
            if abs(lhsMastery - rhsMastery) > 0.001 {
                return lhsMastery > rhsMastery
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        let selected = sortedNodes.prefix(effectiveLimit)
        return selected.map { node in
            KnowledgeCandidate(
                id: node.id,
                name: node.name,
                domain: node.domain,
                mastery: masteryProvider(node.id)
            )
        }
    }

    private static func tokenize(_ text: String) -> Set<String> {
        var tokens = Set<String>()
        var currentWord = ""

        for char in text {
            if char.isLetter || char.isNumber {
                currentWord.append(char)
                if currentWord.count >= 2 {
                    tokens.insert(currentWord)
                }
            } else {
                if !currentWord.isEmpty {
                    tokens.insert(currentWord)
                    currentWord = ""
                }
            }
        }
        if !currentWord.isEmpty {
            tokens.insert(currentWord)
        }
        return tokens
    }
}
