import SwiftUI

struct RealmLadderView: View {
    private let realms = DomainRealm.allCases.filter { $0 != .unstarted }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitleView("境界谱", systemImage: "mountain.2")
            Text("境界同时受领域掌握与知验约束，遗忘不会扣除既得 XP。")
                .font(.callout)
                .foregroundStyle(.secondary)
            ForEach(realms, id: \.rawValue) { realm in
                HStack(spacing: 12) {
                    Circle()
                        .fill(realm == .refining ? AscendTheme.amber : AscendTheme.jade.opacity(0.22))
                        .frame(width: 9, height: 9)
                    Text(realm.title)
                        .bold()
                        .frame(width: 44, alignment: .leading)
                    Text("掌握 ≥ \(Int(realm.minimumScore))")
                    Spacer()
                    Text("\(realm.minimumXP.formatted()) XP")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                if realm != realms.last {
                    Divider()
                }
            }
        }
        .panelCard()
    }
}
