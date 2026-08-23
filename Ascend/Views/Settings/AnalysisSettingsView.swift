import SwiftUI

struct AnalysisSettingsView: View {
    @AppStorage(AnalysisPreferences.batchSizeKey) private var batchSize = AppConstants.defaultAnalysisBatchSize
    @AppStorage(AnalysisPreferences.maximumKnowledgePointsKey) private var maximumKnowledgePoints = AppConstants.defaultMaximumKnowledgePointsPerActivity
    @AppStorage(AnalysisPreferences.repairsMalformedOutputKey) private var repairsMalformedOutput = true
    @AppStorage(AnalysisPreferences.scansBeforeAnalysisKey) private var scansBeforeAnalysis = true

    var body: some View {
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
    }
}
