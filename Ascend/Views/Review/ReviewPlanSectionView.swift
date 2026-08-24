import SwiftUI

struct ReviewPlanSectionView: View {
    let title: String
    let plans: [ReviewPlan]
    let startingPlanID: UUID?
    let nodeName: (ReviewPlan) -> String
    let retention: (ReviewPlan) -> Double?
    let start: ((ReviewPlan) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2)
                .bold()

            ForEach(plans) { plan in
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: plan.status == "due" ? "clock.badge.exclamationmark" : "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(plan.status == "due" ? AscendTheme.cinnabar : AscendTheme.gold)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(nodeName(plan))
                            .font(.headline)
                        Text(plan.scheduledAt, format: .dateTime.year().month().day().hour().minute())
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text(plan.reason)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let value = retention(plan) {
                        LabeledContent("当前可提取率") {
                            Text(value / 100, format: .percent.precision(.fractionLength(0)))
                        }
                        .frame(maxWidth: 180)
                    }

                    if let start {
                        Button(
                            startingPlanID == plan.id ? "准备中…" : "开始复习",
                            systemImage: "brain.head.profile",
                            action: { start(plan) }
                        )
                        .buttonStyle(.borderedProminent)
                        .disabled(startingPlanID != nil)
                    }
                }
                .padding(16)
                .background(Color.primary.opacity(0.04))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }
}
