import SwiftUI

struct KnowledgeNodeGridView: View {
    let nodes: [KnowledgeNode]
    let selectedNodeID: UUID?
    let score: (KnowledgeNode) -> Double
    let action: (KnowledgeNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitleView("知识点", systemImage: "square.grid.2x2")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                ForEach(nodes) { node in
                    Button(action: { action(node) }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(AscendTheme.jade.opacity(0.25), lineWidth: 5)
                                Circle()
                                    .trim(from: 0, to: score(node) / 100)
                                    .stroke(AscendTheme.jade, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Text(Int(score(node).rounded()).formatted())
                                    .font(.callout)
                                    .bold()
                            }
                            .frame(width: 48, height: 48)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(node.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text("\(node.domain) · \(MasteryStage.stage(for: score(node)).rawValue)")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "sidebar.trailing")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(selectedNodeID == node.id ? AscendTheme.jade.opacity(0.10) : .clear)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedNodeID == node.id ? AscendTheme.jade : .secondary.opacity(0.16), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("在检查器中打开掌握详情")
                }
            }
        }
        .panelCard()
    }
}
