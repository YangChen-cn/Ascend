import SwiftUI

struct AnalysisSettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage(AnalysisPreferences.batchSizeKey) private var batchSize = AppConstants.defaultAnalysisBatchSize
    @AppStorage(AnalysisPreferences.maximumKnowledgePointsKey) private var maximumKnowledgePoints = AppConstants.defaultMaximumKnowledgePointsPerActivity
    @AppStorage(AnalysisPreferences.repairsMalformedOutputKey) private var repairsMalformedOutput = true
    @AppStorage(AnalysisPreferences.scansBeforeAnalysisKey) private var scansBeforeAnalysis = true

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("批处理") {
                Stepper("每批活动数：\(batchSize)", value: $batchSize, in: 1...20)
                Text("批次越大，请求次数越少，但单次上下文和 Token 消耗越高。修改会从下一次分析开始生效。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("知识提炼") {
                Stepper("每条活动最多知识点：\(maximumKnowledgePoints)", value: $maximumKnowledgePoints, in: 1...5)
                Text("用于约束模型和本地结果过滤，避免把命令、示例与同一主题的细节过度拆分。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("执行策略") {
                Toggle("分析前自动扫描数据源", isOn: $scansBeforeAnalysis)
                Toggle("结构错误时自动修复一次", isOn: $repairsMalformedOutput)
                Text("格式修复会在首个响应无法安全解析时额外调用一次当前模型，可能产生额外 Token 费用。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("自动 AI 分析") {
                Picker("触发方式", selection: $appState.automaticAnalysisPolicy) {
                    ForEach(AutomaticAnalysisPolicy.allCases) { policy in
                        Text(policy.title).tag(policy)
                    }
                }
                if appState.automaticAnalysisPolicy == .pendingThreshold {
                    Stepper(
                        "待分析达到：\(appState.automaticAnalysisThreshold) 条",
                        value: $appState.automaticAnalysisThreshold,
                        in: 1...100
                    )
                } else if appState.automaticAnalysisPolicy == .daily {
                    Stepper(
                        "每日分析小时：(appState.automaticDailyAnalysisHour)",
                        value: $appState.automaticDailyAnalysisHour,
                        in: 0...23
                    )
                    Stepper(
                        "每日分析分钟：(appState.automaticDailyAnalysisMinute)",
                        value: $appState.automaticDailyAnalysisMinute,
                        in: 0...59
                    )
                    Text("将在每天指定时间之后、且存在待分析活动时执行一次。当天成功后不会重复调用。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text("默认关闭。只有选择“每天一次”或“待分析达到阈值”后，后台才可能调用当前 AI 接口并产生 Token 费用。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("自动准备测评") {
                Toggle("自动准备测评题包", isOn: $appState.automaticAssessmentPreparationEnabled)
                Text("默认关闭。开启后，后台自动化检测到待验证知识点时会自动调用 AI 准备题包；关闭时仅在用户主动发起验证时调用。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("恢复分析默认值", action: restoreDefaults)
            }
        }
        .formStyle(.grouped)
    }

    private func restoreDefaults() {
        batchSize = AppConstants.defaultAnalysisBatchSize
        maximumKnowledgePoints = AppConstants.defaultMaximumKnowledgePointsPerActivity
        repairsMalformedOutput = true
        scansBeforeAnalysis = true
        appState.automaticAnalysisPolicy = .off
        appState.automaticAnalysisThreshold = AutomationPreferences.defaultAnalysisThreshold
        appState.automaticDailyAnalysisHour = AutomationPreferences.defaultDailyAnalysisHour
        appState.automaticDailyAnalysisMinute = AutomationPreferences.defaultDailyAnalysisMinute
        appState.automaticAssessmentPreparationEnabled = false
    }
}
