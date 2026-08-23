import SwiftUI

struct DomainConstellationCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let domain: DomainProgressSnapshot
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(isSelected ? AscendTheme.gold.opacity(0.16) : AscendTheme.cobalt.opacity(0.10))
                        Image(systemName: isSelected ? "sparkles" : "circle.hexagongrid")
                            .foregroundStyle(isSelected ? AscendTheme.gold : AscendTheme.cobalt)
                    }
                    .frame(width: 34, height: 34)

                    Spacer()

                    Text(domain.realm.title)
                        .font(.caption)
                        .foregroundStyle(isSelected ? AscendTheme.jade : .secondary)
                }

                Text(domain.name)
                    .font(.system(.headline, design: .serif))
                    .bold()
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    Label("\(domain.knowledgeCount)", systemImage: "point.3.connected.trianglepath.dotted")
                    Label("\(Int(domain.score.rounded()))", systemImage: "gauge.with.dots.needle.33percent")
                    Label("\(domain.xp)", systemImage: "seal")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(width: 218, alignment: .leading)
            .frame(minHeight: 132, alignment: .leading)
            .background(
                isSelected
                    ? AscendTheme.gold.opacity(colorScheme == .dark ? 0.12 : 0.07)
                    : AscendTheme.surface(for: colorScheme).opacity(0.72)
            )
            .clipShape(.rect(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(
                        isSelected ? AscendTheme.gold : AscendTheme.border(for: colorScheme),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(domain.name)，\(domain.knowledgeCount) 个知识点，掌握度 \(Int(domain.score.rounded()))，境界 \(domain.realm.title)"
        )
        .accessibilityHint("切换到此领域的周天星座脉络图")
    }
}
