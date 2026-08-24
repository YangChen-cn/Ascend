import SwiftUI

struct ChallengeRulesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "scroll.fill")
                    .foregroundStyle(AscendTheme.gold)
                Text(AscendTheme.isXuanqing ? "仙门法轨 · 结算之律" : "挑战结算规则")
                    .font(.system(.headline, design: AscendTheme.titleDesign))
                    .bold()
                Spacer()
                CelestialBadge(title: "铁律", style: .astral)
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("试炼来自下一境所缺的能力条件与关键知窍。", systemImage: "mountain.2.fill")
                    .font(.caption)
                Label("完成动作本身不直接增加掌握或知验，防作弊刷分。", systemImage: "hand.raised.fill")
                    .font(.caption)
                Label("Git 提交、练习或独立解决实据通过验证后方才正式结算。", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                Label("失败与超时绝不扣除既有道行成长。", systemImage: "arrow.uturn.backward.circle.fill")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
