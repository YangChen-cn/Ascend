import SwiftUI

struct MeasurementResetView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    let allowsDeferral: Bool

    init(allowsDeferral: Bool = true) {
        self.allowsDeferral = allowsDeferral
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("升级为可验证掌握估计", systemImage: "checkmark.seal.text.page")
                .font(.title2)
                .bold()

            Text("旧体系根据学习产物推断掌握，不能与新的主动测量结果混用。确认后将重建分析结果。")
                .font(.body)

            VStack(alignment: .leading, spacing: 8) {
                Label("将删除：知识图谱、Evidence、评分、XP、境界、复习、挑战、日报和分析批次", systemImage: "trash")
                Label("将保留：数据源、排除规则、AI 接口、Keychain、偏好与原始 Activity", systemImage: "lock.shield")
                Label("原始 Activity 会恢复为待分析；重新分析后仍需主动答题才会获得掌握与 XP", systemImage: "arrow.clockwise")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                if allowsDeferral {
                    Button("稍后处理", action: dismiss.callAsFunction)
                }
                Spacer()
                Button("确认清理并重建", systemImage: "arrow.triangle.2.circlepath", role: .destructive, action: reset)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 580)
        .accessibilityElement(children: .contain)
    }

    private func reset() {
        do {
            try appState.confirmMeasurementSystemReset()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
