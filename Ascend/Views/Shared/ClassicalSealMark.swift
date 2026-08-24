import SwiftUI

enum ClassicalSealShape: Sendable {
    case square
    case rounded
    case vertical
    case circle
}

enum ClassicalSealStyle: Sendable {
    case cinnabar
    case gold
    case jade
    case ink
}

enum ClassicalSealCarving: Sendable {
    case relief      // 阳刻（透底红边红字）
    case intaglio    // 阴刻（填底朱砂白字）
}

/// 中国传统篆刻金石印章微组件
/// 采用正统金石篆印比例（方印、竖印、引首章），配以朱砂古印泥与泥金色泽
struct ClassicalSealMark: View {
    let text: String
    var shape: ClassicalSealShape = .square
    var style: ClassicalSealStyle = .cinnabar
    var carving: ClassicalSealCarving = .intaglio
    var size: CGFloat = 22

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if AscendTheme.isXuanqing {
            sealContent
                .accessibilityLabel("印记：\(text)")
        } else {
            // 清简模式下降级为极简小标签
            Text(text)
                .font(.system(size: max(9, size * 0.5), weight: .medium, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.secondary)
        }
    }

    private var sealContent: some View {
        ZStack {
            // 印章底色
            sealBackground

            // 篆刻文字
            if shape == .vertical && text.count > 1 {
                VStack(spacing: -1) {
                    ForEach(Array(text), id: \.self) { char in
                        Text(String(char))
                            .font(.system(size: size * 0.44, weight: .bold, design: .serif))
                            .foregroundStyle(carving == .intaglio ? intaglioTextColor : sealColor)
                    }
                }
                .padding(2)
            } else {
                Text(text)
                    .font(.system(size: fontSize, weight: .bold, design: .serif))
                    .foregroundStyle(carving == .intaglio ? intaglioTextColor : sealColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(text.count > 2 ? 2 : 1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
            }

            // 阳刻内边线
            if carving == .relief {
                RoundedRectangle(cornerRadius: cornerRadius * 0.6)
                    .strokeBorder(sealColor.opacity(0.8), lineWidth: 0.8)
                    .padding(2)
            }
        }
        .frame(width: sealWidth, height: sealHeight)
        .overlay {
            // 金石印章外框微痕
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    sealColor.opacity(carving == .intaglio ? 0.45 : 0.9),
                    lineWidth: 1.0
                )
        }
        .shadow(color: sealColor.opacity(colorScheme == .dark ? 0.30 : 0.18), radius: 2, y: 1)
    }

    private var cornerRadius: CGFloat {
        switch shape {
        case .square: 3
        case .rounded: 5
        case .vertical: 3
        case .circle: size / 2
        }
    }

    private var sealWidth: CGFloat {
        switch shape {
        case .square:
            return text.count > 2 ? size * 1.3 : size
        case .rounded:
            return max(size, CGFloat(text.count) * (size * 0.55) + 6)
        case .vertical:
            return size * 0.85
        case .circle:
            return size
        }
    }

    private var sealHeight: CGFloat {
        switch shape {
        case .square:
            return size
        case .rounded:
            return size * 0.95
        case .vertical:
            return CGFloat(max(1, text.count)) * (size * 0.55) + 6
        case .circle:
            return size
        }
    }

    private var fontSize: CGFloat {
        if text.count == 1 {
            return size * 0.58
        } else if text.count == 2 {
            return size * 0.44
        } else {
            return size * 0.36
        }
    }

    @ViewBuilder
    private var sealBackground: some View {
        let isIntaglio = (carving == .intaglio)
        let fill = isIntaglio ? sealColor : sealColor.opacity(0.08)

        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(fill)
    }

    private var sealColor: Color {
        switch style {
        case .cinnabar:
            Color(red: 0.76, green: 0.20, blue: 0.16) // 古法朱砂印泥
        case .gold:
            Color(red: 0.78, green: 0.56, blue: 0.15) // 泥金印
        case .jade:
            Color(red: 0.10, green: 0.52, blue: 0.40) // 墨玉印
        case .ink:
            colorScheme == .dark ? Color(white: 0.80) : Color(red: 0.18, green: 0.20, blue: 0.22)
        }
    }

    private var intaglioTextColor: Color {
        switch style {
        case .cinnabar:
            Color(red: 0.99, green: 0.98, blue: 0.95) // 象牙白字
        case .gold:
            Color(red: 0.15, green: 0.12, blue: 0.05)
        case .jade:
            Color.white
        case .ink:
            colorScheme == .dark ? Color.black : Color.white
        }
    }
}
