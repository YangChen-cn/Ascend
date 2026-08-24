import SwiftUI

struct AssessmentOptionList: View {
    let title: String
    let options: [String]
    @Binding var selection: Int?
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(options.indices, id: \.self) { index in
                Button(action: { selection = index }) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: selection == index ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selection == index ? AscendTheme.jade : .secondary)
                        Text(options[index])
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .accessibilityLabel("选项 \(index + 1)：\(options[index])")
                .accessibilityValue(selection == index ? "已选择" : "未选择")
                .padding(9)
                .background(selection == index ? AscendTheme.jade.opacity(0.10) : Color.primary.opacity(0.03))
                .clipShape(.rect(cornerRadius: 8))
            }
        }
    }
}
