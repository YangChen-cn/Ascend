import SwiftUI

struct ChallengeCardView: View {
    let challenge: Challenge
    let action: (Challenge) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Label(challenge.title, systemImage: "flag.checkered")
                    .font(.title2)
                    .bold()
                Spacer()
                Text("+\(challenge.rewardXP) XP")
                    .bold()
                    .foregroundStyle(AscendTheme.jade)
            }
            Text(challenge.challengeDescription)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Label("\(challenge.estimatedMinutes) 分钟", systemImage: "clock")
                Spacer()
                Label("\(challenge.knowledgeNodeIDs.count) 个知识点", systemImage: "point.3.connected.trianglepath.dotted")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            Divider()
            ForEach(challenge.requirements.prefix(4), id: \.self) { requirement in
                Label(requirement, systemImage: "circle")
                    .font(.callout)
            }
            Spacer(minLength: 0)
            Button("开始挑战", systemImage: "play.fill", action: { action(challenge) })
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)
        }
        .panelCard()
    }
}
