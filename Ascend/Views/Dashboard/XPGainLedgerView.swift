import SwiftUI

struct XPGainLedgerView: View {
    let items: [XPGainItem]

    private var totalXP: Int { items.reduce(0) { $0 + $1.xp } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitleView("今日获得")
                Text("+\(totalXP.formatted()) XP")
                    .font(.title2)
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(AscendTheme.jade)
            }
            ForEach(items) { item in
                HStack {
                    Label(item.title, systemImage: item.systemImage)
                    Spacer()
                    Text("+\(item.xp) XP")
                        .foregroundStyle(.secondary)
                }
                Divider()
            }
        }
    }
}
