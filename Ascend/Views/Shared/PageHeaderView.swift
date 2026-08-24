import SwiftUI

struct PageHeaderView: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    init(_ title: String, subtitle: String? = nil, systemImage: String) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(AscendTheme.isXuanqing ? AscendTheme.gold.opacity(0.12) : AscendTheme.jade.opacity(0.10))
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(AscendTheme.isXuanqing ? AscendTheme.gold.opacity(0.36) : AscendTheme.jade.opacity(0.22))
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(AscendTheme.isXuanqing ? AscendTheme.gold : AscendTheme.jade)
            }
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.largeTitle, design: AscendTheme.titleDesign))
                    .bold()
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AscendTheme.gold.opacity(AscendTheme.isXuanqing ? 0.30 : 0.14))
                .frame(height: 1)
        }
    }
}
