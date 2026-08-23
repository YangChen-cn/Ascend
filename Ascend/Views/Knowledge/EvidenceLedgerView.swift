import SwiftUI

struct EvidenceLedgerView: View {
    @Environment(AppState.self) private var appState
    let nodeID: UUID

    private var evidence: [EvidenceRecord] {
        appState.evidenceRecords.filter { $0.knowledgeNodeID == nodeID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleView("为什么是这个分数")
            ForEach(evidence.prefix(6)) { item in
                HStack {
                    Label(item.kind.title, systemImage: icon(for: item.kind))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.isVerified ? "强证据" : "待确认")
                        .foregroundStyle(item.isVerified ? AscendTheme.jade : AscendTheme.amber)
                    Text(item.kind == .independentSolve ? "+8" : "+3")
                        .bold()
                        .foregroundStyle(AscendTheme.jade)
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
