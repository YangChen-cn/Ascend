import SwiftUI

/// 今日页的日报摘要，以主叙述与可扫读的证据标签分层展示。
struct TodayInsightCardView: View {
    let presentation: DailyDigestPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("今日所学", systemImage: "sparkles")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(AscendTheme.gold)

                if let xpSummary = presentation.xpSummary {
                    Text(xpSummary)
                        .font(.caption)
                        .foregroundStyle(AscendTheme.gold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AscendTheme.gold.opacity(0.11))
                        .clipShape(.capsule)
                }

                Spacer(minLength: 0)
            }

            Text(presentation.primaryText)
                .font(.body)
                .lineLimit(3)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                if let growth = presentation.strongestGrowth {
                    Label(growth, systemImage: "chart.line.uptrend.xyaxis")
                }
                if let review = presentation.reviewSummary {
                    Label(review, systemImage: "clock.arrow.circlepath")
                }
                if let challenge = presentation.challengeSummary {
                    Label(challenge, systemImage: "flag.checkered")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            if let nextStep = presentation.nextStep {
                Label(nextStep, systemImage: "arrowshape.turn.up.right")
                    .font(.caption)
                    .foregroundStyle(AscendTheme.inkJade)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 14)
        .padding(.vertical, 2)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(AscendTheme.gold.opacity(0.72))
                .frame(width: 3)
        }
        .accessibilityElement(children: .combine)
    }
}
