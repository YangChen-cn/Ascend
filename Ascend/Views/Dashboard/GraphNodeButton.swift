import SwiftUI

struct GraphNodeButton: View {
    let node: KnowledgeNode
    let mastery: Double
    let isCenter: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(node.name)
                    .bold()
                    .multilineTextAlignment(.center)
                Text(Int(mastery.rounded()).formatted())
                    .font(isCenter ? .title : .headline)
                    .foregroundStyle(AscendTheme.jade)
                Text(MasteryStage.stage(for: mastery).rawValue)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(width: isCenter ? 132 : 104, height: isCenter ? 132 : 104)
            .background(.background)
            .clipShape(.circle)
            .overlay {
                Circle()
                    .stroke(isHovered ? AscendTheme.cobalt : AscendTheme.jade, lineWidth: isCenter ? 3 : 2)
            }
            .shadow(color: isHovered ? AscendTheme.cobalt.opacity(0.18) : .clear, radius: 12)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(node.name)，掌握度 \(Int(mastery.rounded()))，\(MasteryStage.stage(for: mastery).rawValue)")
    }
}
