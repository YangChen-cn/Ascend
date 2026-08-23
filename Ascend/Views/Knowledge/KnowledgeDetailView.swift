import SwiftUI

struct KnowledgeDetailView: View {
    @Environment(AppState.self) private var appState
    let node: KnowledgeNode
    let mastery: MasteryState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("\(node.domain) · \(node.name)")
                    .foregroundStyle(.secondary)
                Text(node.name)
                    .font(.largeTitle)
                    .bold()

                HStack(alignment: .center, spacing: 24) {
                    MasteryRingView(score: mastery.composite)
                    VStack(alignment: .leading, spacing: 12) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 12)], alignment: .leading, spacing: 12) {
                            LabeledContent("境界", value: mastery.stage.rawValue)
                            LabeledContent("置信度", value: "\(Int(mastery.confidence.rounded()))%")
                            LabeledContent("本周变化", value: "+\(appState.weeklyChange(for: node.id))")
                        }
                        ProgressView(value: Double(mastery.lifetimeXP % 800), total: 800)
                            .tint(AscendTheme.jade)
                        LabeledContent("悟得") {
                            Text(appState.latestInsight(for: node.id) ?? "尚无已验证的悟得；继续积累解释、实践或独立解决证据。")
                                .multilineTextAlignment(.leading)
                        }
                        .padding(12)
                        .background(AscendTheme.cobalt.opacity(0.06))
                        .clipShape(.rect(cornerRadius: 8))
                    }
                }

                Divider()
                MasteryDimensionStrip(vector: mastery.vector)
                Divider()
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 22) {
                        EvidenceLedgerView(nodeID: node.id)
                            .frame(width: 260)
                        MasteryTrajectoryView(currentScore: mastery.composite)
                            .frame(width: 300)
                    }
                    VStack(alignment: .leading, spacing: 24) {
                        EvidenceLedgerView(nodeID: node.id)
                        MasteryTrajectoryView(currentScore: mastery.composite)
                    }
                }
                Divider()
                KnowledgeRelationsView(nodeID: node.id)
                Divider()
                NextStageView(mastery: mastery)
            }
            .padding(26)
        }
        .background(FeaturePageBackground())
    }
}
