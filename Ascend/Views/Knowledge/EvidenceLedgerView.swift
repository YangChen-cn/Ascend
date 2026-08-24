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
                    Text(item.verificationLevel.isDirectPerformance ? "表现已验证" : (item.isVerified ? "材料已归类" : "待确认"))
                        .foregroundStyle(item.verificationLevel.isDirectPerformance ? AscendTheme.jade : AscendTheme.amber)
                    if item.verificationLevel == .artifactCandidate {
                        Menu(item.assistanceMode.title) {
                            ForEach(AssistanceMode.allCases) { mode in
                                Button(mode.title) {
                                    appState.setArtifactAssistanceMode(mode, for: item.id)
                                }
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .help("仅记录创作方式，不参与掌握估计")
                    }
                    if let ledger = ledgerByEvidenceID[item.id] {
                        Text(
                            "+\(max(0, ledger.newComposite - ledger.previousComposite), format: .number.precision(.fractionLength(1)))"
                        )
                            .monospacedDigit()
                            .bold()
                            .foregroundStyle(AscendTheme.jade)
                            .help("历史掌握 \(ledger.previousComposite.formatted()) → \(ledger.newComposite.formatted())")
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
