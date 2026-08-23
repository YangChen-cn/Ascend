import SwiftUI

struct ReviewGradeButtonsView: View {
    let onSelect: (MemoryReviewGrade) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("此次回忆如何？")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(MemoryReviewGrade.allCases) { grade in
                    Button(grade.title, action: { onSelect(grade) })
                        .buttonStyle(.bordered)
                        .accessibilityLabel("复习结果：\(grade.title)")
                }
            }
        }
    }
}
