import SwiftUI

struct EvidenceLedgerView: View {
    @Environment(AppState.self) private var appState
    let nodeID: UUID

    private var evidence: [EvidenceRecord] {
        appState.evidenceRecords(for: nodeID)
    }

    private var ledgerByEvidenceID: [UUID: ScoreLedgerEntry] {
        Dictionary(uniqueKeysWithValues: appState.ledgerEntries(for: nodeID).map { ($0.evidenceID, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleView("为什么是这个分数")
            ForEach(evidence.prefix(6)) { item in
                HStack {
                    Label(item.kind.title, systemImage: icon(for: item.kind))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let ledger = ledgerByEvidenceID[item.id] {
                        Text(ledger.xpAwarded > 0 ? "+\(ledger.xpAwarded) XP" : "能力记录")
                            .monospacedDigit()
                            .bold()
                            .foregroundStyle(ledger.xpAwarded > 0 ? AscendTheme.jade : .secondary)
                            .help("历史掌握 \(ledger.previousComposite.formatted()) → \(ledger.newComposite.formatted())，知验 +\(ledger.xpAwarded)")
                    } else {
                        Text("未计分")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 5)
                Divider()
            }
            if evidence.isEmpty {
                ContentUnavailableView("暂无证据", systemImage: "tray")
            }
        }
    }

    private func icon(for kind: EvidenceKind) -> String {
        switch kind {
        case .exposure: "eye"
        case .explanation: "doc.text"
        case .exercise: "checklist"
        case .project: "arrow.triangle.branch"
        case .review: "clock.arrow.circlepath"
        case .independentSolve: "ladybug"
        }
    }
}
