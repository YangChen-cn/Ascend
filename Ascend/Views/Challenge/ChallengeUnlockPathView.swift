import SwiftUI

struct ChallengeUnlockPathView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitleView("挑战如何解锁", systemImage: "key")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                OnboardingStepView(number: 1, title: "发现短板", detail: "从掌握维度、遗忘与知脉中定位缺口", systemImage: "scope")
                OnboardingStepView(number: 2, title: "生成课题", detail: "AI 给出能产出真实证据的实践任务", systemImage: "wand.and.stars")
                OnboardingStepView(number: 3, title: "证据结算", detail: "后续行为验证完成条件并写入账本", systemImage: "checkmark.seal")
            }
        }
        .panelCard()
    }
}
