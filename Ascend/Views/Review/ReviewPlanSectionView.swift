import SwiftUI

struct ReviewPlanSectionView: View {
    let title: String
    let systemImage: String
    let plans: [ReviewPlan]
    let startingPlanID: UUID?
    let start: ((ReviewPlan) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(title.contains("现在") ? AscendTheme.cinnabar : AscendTheme.gold)
                    .font(.headline)

                Text(title)
                    .font(.system(.title3, design: AscendTheme.titleDesign))
                    .bold()

                Spacer()

                CelestialBadge(
                    title: "\(plans.count)",
                    style: title.contains("现在") ? .cinnabar : .gold
                )
            }

            VStack(spacing: 12) {
                ForEach(plans) { plan in
                    ReviewPlanCardView(
                        plan: plan,
                        isStarting: startingPlanID == plan.id,
                        onStart: start.map { action in { action(plan) } }
                    )
                }
            }
        }
    }
}
