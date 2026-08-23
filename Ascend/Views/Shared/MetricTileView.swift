import SwiftUI

struct MetricTileView: View {
    let title: String
    let value: String
    let systemImage: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title, design: .rounded))
                .bold()
                .foregroundStyle(AscendTheme.jade)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
    }
}
