import SwiftUI

struct MenuBarTodaySummary: View {
    @Environment(AppState.self) private var appState

    private var todayEvidence: [EvidenceRecord] {
        appState.evidenceRecords.filter {
            $0.isVerified && Calendar.current.isDateInToday($0.timestamp)
        }
    }

    private func topicNames(from evidenceRecords: [EvidenceRecord]) -> [String] {
        var seen = Set<UUID>()
        return evidenceRecords.compactMap { evidence in
            guard seen.insert(evidence.knowledgeNodeID).inserted else { return nil }
            return appState.node(for: evidence.knowledgeNodeID)?.name
        }
    }

    private var digestLearningSummary: String? {
        guard let digest = appState.digests.first(where: { Calendar.current.isDateInToday($0.date) }) else {
            return nil
        }
        return digest.summary
            .split(whereSeparator: \Character.isNewline)
            .map(String.init)
            .first(where: { $0.hasPrefix("今日所学：") })?
            .replacingOccurrences(of: "今日所学：", with: "")
    }

    private func learningText(topicNames: [String]) -> String {
        if !topicNames.isEmpty {
            let visible = topicNames.prefix(4).joined(separator: " · ")
            return topicNames.count > 4 ? visible + " 等" : visible
        }
        return digestLearningSummary ?? "今日尚无已验证所学"
    }

    private var newKnowledgeCount: Int {
        appState.knowledgeNodes.count {
            !$0.isProvisional && Calendar.current.isDateInToday($0.createdAt)
        }
    }

    private func practiceCount(from evidenceRecords: [EvidenceRecord]) -> Int {
        let practicalKinds: Set<EvidenceKind> = [.exercise, .project, .independentSolve]
        let keys = evidenceRecords.reduce(into: Set<String>()) { result, evidence in
            guard practicalKinds.contains(evidence.kind) else { return }
            let provenance = evidence.contentChangeHash ?? evidence.fingerprint
            result.insert("\(provenance):\(evidence.knowledgeNodeID.uuidString)")
        }
        return keys.count
    }

    var body: some View {
        let evidenceRecords = todayEvidence
        let topics = topicNames(from: evidenceRecords)

        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label("今日所学", systemImage: "book.pages")
                    .font(.system(.caption, design: .serif))
                    .bold()

                Spacer()

                Text("+\(appState.todayXPGains.reduce(0) { $0 + $1.xp }) XP")
                    .font(.caption.monospacedDigit())
                    .bold()
                    .foregroundStyle(AscendTheme.gold)
            }

            Text(learningText(topicNames: topics))
                .font(.system(.subheadline, design: .serif))
                .lineLimit(2)
                .foregroundStyle(topics.isEmpty && digestLearningSummary == nil ? .secondary : .primary)

            Text("新增 \(newKnowledgeCount) · 深化 \(appState.todayMasteryChanges.count) · 实践 \(practiceCount(from: evidenceRecords))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}
