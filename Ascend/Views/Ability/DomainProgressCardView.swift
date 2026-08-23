import SwiftUI

struct DomainProgressCardView: View {
    let domain: DomainProgressSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(domain.name)
                        .font(.system(.title2, design: .serif))
                        .bold()
                    Text("\(domain.knowledgeCount) 个知识点 · \(domain.xp.formatted()) XP")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(domain.realm.title)
                    .font(.headline)
                    .foregroundStyle(AscendTheme.jade)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AscendTheme.jade.opacity(0.10))
                    .clipShape(.capsule)
            }

            HStack(alignment: .lastTextBaseline) {
                Text(Int(domain.score.rounded()).formatted())
                    .font(.system(.largeTitle, design: .rounded))
                    .bold()
                Text("掌握")
                    .foregroundStyle(.secondary)
                Spacer()
                if let next = domain.nextRealm {
                    Text("下一境 · \(next.title)")
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: domain.score, total: 100)
                .tint(AscendTheme.jade)
            if let next = domain.nextRealm {
                HStack {
                    Label("掌握 ≥ \(Int(next.minimumScore))", systemImage: "gauge.with.dots.needle.33percent")
                    Spacer()
                    Label("\(next.minimumXP.formatted()) XP", systemImage: "seal")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            } else {
                Label("此域已臻通达", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(AscendTheme.jade)
            }
        }
        .panelCard()
    }
}
