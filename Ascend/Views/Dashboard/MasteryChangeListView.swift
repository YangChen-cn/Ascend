import SwiftUI

struct MasteryChangeListView: View {
    let metrics: [DashboardMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleView("能力变化")
            ForEach(metrics) { metric in
                HStack {
                    Text(metric.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(Int(metric.previous.formatted())) → \(Int(metric.current.formatted()))")
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text("+\(Int(metric.current - metric.previous))")
                        .font(.callout)
                        .monospacedDigit()
                        .bold()
                        .foregroundStyle(AscendTheme.jade)
                }
                Divider()
            }
        }
    }
}
