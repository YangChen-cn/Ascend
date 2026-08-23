import Charts
import SwiftUI

struct MasteryTrajectoryView: View {
    @Environment(AppState.self) private var appState
    let nodeID: UUID

    private var points: [TrajectoryPoint] {
        TrajectoryPoint.make(from: entries)
    }

    private var entries: [ScoreLedgerEntry] {
        appState.ledgerEntries(for: nodeID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleView("掌握轨迹")
            if points.count >= 2 {
                Chart(points) { point in
                    LineMark(
                        x: .value("时间", point.timestamp),
                        y: .value("掌握度", point.score)
                    )
                    .foregroundStyle(AscendTheme.jade)
                    PointMark(
                        x: .value("时间", point.timestamp),
                        y: .value("掌握度", point.score)
                    )
                    .foregroundStyle(AscendTheme.jade)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 220)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entries.suffix(4).reversed()) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.timestamp, format: .dateTime.month().day().hour().minute())
                                Spacer()
                                Text("\(Int(entry.previousComposite.rounded())) → \(Int(entry.newComposite.rounded()))")
                                    .monospacedDigit()
                                    .foregroundStyle(AscendTheme.jade)
                            }
                            .font(.caption)
                            Text(entry.reason.isEmpty ? "已验证学习证据" : entry.reason)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "尚无足够的真实掌握轨迹",
                    systemImage: "chart.xyaxis.line",
                    description: Text("完成更多已验证学习活动后将在此形成成长曲线。")
                )
                .frame(minHeight: 220)
            }
        }
    }
}
