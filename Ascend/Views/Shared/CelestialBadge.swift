import SwiftUI

enum CelestialBadgeStyle {
    case jade
    case gold
    case cinnabar
    case astral
    case neutral
}

struct CelestialBadge: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var style: CelestialBadgeStyle = .jade

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.bold())
            }
            Text(title)
                .font(.caption)
                .bold()
            if let subtitle {
                Text(subtitle)
                    .font(.system(.caption2, design: .rounded))
                    .opacity(0.85)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(backgroundGradient)
        .foregroundStyle(textColor)
        .clipShape(.rect(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.8)
        }
    }

    private var backgroundGradient: LinearGradient {
        switch style {
        case .jade:
            LinearGradient(
                colors: [AscendTheme.jade.opacity(0.22), AscendTheme.deepJade.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gold:
            LinearGradient(
                colors: [AscendTheme.gold.opacity(0.25), Color.orange.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cinnabar:
            LinearGradient(
                colors: [AscendTheme.cinnabar.opacity(0.24), AscendTheme.cinnabar.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .astral:
            LinearGradient(
                colors: AscendTheme.isXuanqing
                    ? [AscendTheme.jade.opacity(0.20), AscendTheme.deepJade.opacity(0.10)]
                    : [AscendTheme.cobalt.opacity(0.22), Color.indigo.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neutral:
            LinearGradient(
                colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var textColor: Color {
        switch style {
        case .jade: AscendTheme.jade
        case .gold: AscendTheme.gold
        case .cinnabar: AscendTheme.cinnabar
        case .astral: AscendTheme.cobalt
        case .neutral: .secondary
        }
    }

    private var borderColor: Color {
        switch style {
        case .jade: AscendTheme.jade.opacity(0.45)
        case .gold: AscendTheme.gold.opacity(0.55)
        case .cinnabar: AscendTheme.cinnabar.opacity(0.50)
        case .astral: AscendTheme.cobalt.opacity(0.45)
        case .neutral: Color.primary.opacity(0.15)
        }
    }
}
