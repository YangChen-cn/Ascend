import SwiftUI

struct SheetHeaderView<Actions: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    @ViewBuilder let actions: Actions

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(AscendTheme.isXuanqing ? AscendTheme.gold : AscendTheme.jade)
                .frame(width: 30, height: 30)
                .background(AscendTheme.gold.opacity(AscendTheme.isXuanqing ? 0.10 : 0.04), in: .rect(cornerRadius: 7))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.title2, design: AscendTheme.titleDesign))
                    .bold()
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)
            actions
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
