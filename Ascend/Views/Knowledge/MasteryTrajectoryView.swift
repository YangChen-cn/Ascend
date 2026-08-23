import Charts
import SwiftUI

struct MasteryTrajectoryView: View {
    let currentScore: Double

    private var points: [TrajectoryPoint] {
        [
            .init(day: 1, score: 25, label: "首次学习"),
            .init(day: 6, score: 35, label: nil),
            .init(day: 10, score: 43, label: "完成练习"),
            .init(day: 16, score: 56, label: "项目应用"),
            .init(day: 20, score: 65, label: "独立调试"),
            .init(day: 23, score: currentScore, label: nil)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleView("掌握轨迹")
            Chart(points) { point in
                LineMark(
                    x: .value("日期", point.day),
                    y: .value("掌握度", point.score)
                )
                .foregroundStyle(AscendTheme.jade)
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("日期", point.day),
                    y: .value("掌握度", point.score)
                )
                .foregroundStyle(AscendTheme.jade)
                if let label = point.label {
                    RuleMark(x: .value("事件", point.day))
                        .foregroundStyle(.secondary.opacity(0.35))
                        .annotation(position: .top) { Text(label).font(.callout) }
                }
            }
            .chartXScale(domain: 1...23)
            .chartYScale(domain: 0...100)
            .frame(height: 240)
        }
    }
}
