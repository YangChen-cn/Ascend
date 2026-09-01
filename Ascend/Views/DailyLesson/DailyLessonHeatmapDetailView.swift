import SwiftUI

/// 热力图格子的常驻详情：悬停即时切换，点击后固定，避免小格上的浮层被滚动容器裁切。
struct DailyLessonHeatmapDetailView: View {
    let cell: DailyLessonHeatmapCell
    let isPinned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: cell.hasLearningActivity ? "flame.fill" : "calendar")
                    .foregroundStyle(cell.hasLearningActivity ? AscendTheme.gold : AscendTheme.jade)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(cell.day, format: .dateTime.year().month().day().weekday(.wide))
                        .font(.caption)
                        .bold()
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(isPinned ? "已选中" : "悬停预览")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !cell.learningActivities.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(cell.learningActivities) { activity in
                        Label(activity.title, systemImage: "doc.text")
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.leading, 30)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AscendTheme.jade.opacity(0.06))
        .clipShape(.rect(cornerRadius: AscendTheme.Radius.control))
        .accessibilityElement(children: .combine)
    }

    private var detailText: String {
        "日课完成 \(cell.completionCount) 项 · 真实学习 \(cell.learningActivityCount) 条"
    }
}
