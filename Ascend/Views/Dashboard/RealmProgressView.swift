import SwiftUI

struct RealmProgressView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitleView("领域境界", systemImage: "mountain.2")
                .foregroundStyle(AscendTheme.cobalt)
            if appState.domainProgress.isEmpty {
                Text("知识点归入领域后，每个领域会独立计算掌握度、XP 与境界。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.domainProgress.prefix(4)) { domain in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(domain.name).bold()
                            Spacer()
                            Text(domain.realm.title)
                                .foregroundStyle(AscendTheme.jade)
                        }
                        ProgressView(value: domain.xpProgress)
                            .tint(AscendTheme.jade)
                        HStack {
                            Text("\(domain.xp.formatted()) XP")
                            Spacer()
                            if let next = domain.nextRealm {
                                Text("下一境界：\(next.title) · \(next.minimumXP.formatted()) XP")
                            }
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
