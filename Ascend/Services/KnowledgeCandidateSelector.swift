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

            // 1. Exact / phrase name match
            if !normalizedName.isEmpty, activityText.contains(normalizedName) {
                score += 20.0
            }

            // 2. Knowledge name token overlap
            let nameTokens = tokenize(normalizedName)
            let overlapCount = nameTokens.intersection(activityTokens).count
            if overlapCount > 0 {
                score += Double(overlapCount) * 6.0
            }

            // 3. Domain match / overlap
            if !normalizedDomain.isEmpty, activityText.contains(normalizedDomain) {
                score += 3.0
            }

            let domainTokens = tokenize(normalizedDomain)
            let domainOverlap = domainTokens.intersection(activityTokens).count
            if domainOverlap > 0 {
                score += Double(domainOverlap) * 1.5
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

        // Sort strictly by relevance score, with alphabetical stable tie-break
        let sortedNodes = allNodes.sorted { lhs, rhs in
            let lhsScore = totalScores[lhs.id, default: 0]
            let rhsScore = totalScores[rhs.id, default: 0]
            if abs(lhsScore - rhsScore) > 0.001 {
                return lhsScore > rhsScore
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
