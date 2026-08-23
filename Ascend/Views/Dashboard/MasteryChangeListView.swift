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
                    Text(metric.previous.formatted())
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.tertiary)
                    Text(metric.current.formatted())
                        .bold()
                        .foregroundStyle(AscendTheme.jade)
                    Text("↑\(metric.current - metric.previous)")
                        .font(.callout)
                        .foregroundStyle(AscendTheme.jade)
                }
                Divider()
            }
        }
    }
}
