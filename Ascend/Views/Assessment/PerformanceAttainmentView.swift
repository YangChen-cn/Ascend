import SwiftUI

/// 实作认证登记表单：把真实项目中的独立实作登记为生产性证据（0 AI）。
/// 化用（80 分）需要 1 次实作认证，通达（90 分）需要两次不同情境、
/// 间隔 ≥7 天的实作认证；同一情境只认证一次。
struct PerformanceAttainmentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let node: KnowledgeNode

    enum AttainmentMethod: String, CaseIterable {
        case rubric = "量规自评"
        case deterministic = "确定性验证"

        var hint: String {
            switch self {
            case .rubric: "对照三条量规逐条确认，全部满足才可通过"
            case .deterministic: "测试、构建或 CI 等客观结果，如实填写结果说明"
            }
        }
    }

    @State private var contextName = ""
    @State private var detail = ""
    @State private var declaredUnassisted = false
    @State private var method: AttainmentMethod = .rubric
    @State private var rubricInRealProject = false
    @State private var rubricIndependentlySolved = false
    @State private var rubricMetExpectedQuality = false
    @State private var deterministicOutcome = ""
    @State private var deterministicPassed = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var rubricFullyChecked: Bool {
        rubricInRealProject && rubricIndependentlySolved && rubricMetExpectedQuality
    }

    private var canSubmit: Bool {
        guard !contextName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              declaredUnassisted, !isSubmitting else { return false }
        switch method {
        case .rubric:
            return rubricFullyChecked
        case .deterministic:
            return !deterministicOutcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    contextSection
                    independenceSection
                    methodSection

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(AscendTheme.cinnabar)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(action: submit) {
                    if isSubmitting {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("登记中…")
                        }
                    } else {
                        Text("登记实作认证")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 520)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("登记实作认证")
                .font(.system(.title2, design: AscendTheme.titleDesign))
                .bold()
            Text("把「\(node.name)」在真实项目中的独立实作登记为生产性证据，用于突破化用与通达。全程本地结算，0 AI 请求。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("实作情境", systemImage: "square.grid.2x2")

            TextField("项目或情境名称（如：命令行工具重构、并发模块 v2）", text: $contextName)
                .textFieldStyle(.roundedBorder)

            TextField("补充说明（可选）：做了什么、结果如何", text: $detail, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            Text("同一情境只认证一次；通达需要两次不同情境、间隔至少 7 天的独立实作。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var independenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("独立声明", systemImage: "person.crop.circle.badge.checkmark")

            Toggle("本次实作未借助资料、提示或 AI，由我独立完成", isOn: $declaredUnassisted)

            Text("独立实作是化用与通达的必要条件；借助辅助的练习仍会通过日常学习被记录，但不计入实作认证。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("认证方式", systemImage: "checkmark.seal")

            Picker("认证方式", selection: $method) {
                ForEach(AttainmentMethod.allCases, id: \.self) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)

            Text(method.hint)
                .font(.caption)
                .foregroundStyle(.secondary)

            switch method {
            case .rubric:
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("实作发生在真实项目或工作情境中（非练习题、非照抄教程）", isOn: $rubricInRealProject)
                    Toggle("我独立解决了其中的核心问题，未依赖逐步指引", isOn: $rubricIndependentlySolved)
                    Toggle("实作结果达到我或团队预期的质量要求", isOn: $rubricMetExpectedQuality)

                    if !rubricFullyChecked {
                        Text("三条量规需全部满足才可通过认证——请如实勾选，未满足时可先积累更多真实实作。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            case .deterministic:
                VStack(alignment: .leading, spacing: 8) {
                    Picker("结果", selection: $deterministicPassed) {
                        Text("通过（测试 / 构建全部通过）").tag(true)
                        Text("未通过").tag(false)
                    }
                    .pickerStyle(.radioGroup)

                    TextField("结果说明（如：unit tests 42 passed, CI green）", text: $deterministicOutcome, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                }
            }
        }
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(.callout, design: AscendTheme.titleDesign))
            .bold()
    }

    private func submit() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        let trimmedContext = contextName.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = composeSummary(context: trimmedContext)
        do {
            try appState.recordVerifiedPerformance(
                for: node.id,
                contextHash: normalizedContextHash(trimmedContext),
                summary: summary,
                score: method == .deterministic ? (deterministicPassed ? 1 : 0) : 0.9,
                scoringConfidence: 0.9,
                verificationLevel: method == .deterministic ? .productionDeterministic : .productionRubric,
                assistanceMode: .declaredUnassisted
            )
            appState.statusMessage = "实作认证已登记：\(node.name) · \(trimmedContext)"
            dismiss()
        } catch {
            errorMessage = friendlyError(error)
        }
        isSubmitting = false
    }

    private func composeSummary(context: String) -> String {
        let detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        switch method {
        case .rubric:
            return detail.isEmpty ? "真实项目独立实作 · \(context)" : "真实项目独立实作 · \(context)：\(detail)"
        case .deterministic:
            let outcome = deterministicOutcome.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = deterministicPassed ? "通过" : "未通过"
            return "确定性验证\(result) · \(context)：\(outcome)"
        }
    }

    /// 情境名规范化哈希：大小写与空白差异不产生新情境，保证「同一情境只认证一次」稳定判定
    private func normalizedContextHash(_ context: String) -> String {
        let normalized = context.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return "context:" + normalized
    }

    private func friendlyError(_ error: Error) -> String {
        if let assessmentError = error as? AssessmentFlowError {
            switch assessmentError {
            case .duplicatePerformanceContext:
                return "该情境已登记过实作认证；请换一个真实情境再试。"
            case .invalidPerformanceReceipt:
                return "登记信息不完整，请检查情境名称与独立声明。"
            case .lowPerformanceConfidence:
                return "认证置信度不足：量规需全部满足后重试。"
            default:
                break
            }
        }
        return "登记失败：\(error.localizedDescription)"
    }
}
