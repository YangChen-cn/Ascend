import SwiftUI

struct ChallengeRulesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitleView("结算之律", systemImage: "scroll")
            Label("挑战来自下一境所缺的能力条件", systemImage: "mountain.2")
            Label("完成动作本身不直接增加掌握或 XP", systemImage: "hand.raised")
            Label("Git、练习、复习或独立解决证据通过验证后结算", systemImage: "checkmark.seal")
            Label("失败和超时不会扣除既有成长", systemImage: "arrow.uturn.backward.circle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.secondary)
        .panelCard()
    }
}
