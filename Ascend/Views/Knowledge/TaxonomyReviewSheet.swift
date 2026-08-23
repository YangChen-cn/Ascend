import SwiftUI

struct TaxonomyReviewSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var mergingSuggestionID: UUID?
    @State private var selectedMergeTargetID: UUID?

    private var pendingSuggestions: [TaxonomySuggestion] {
        appState.taxonomySuggestions.filter { $0.status == "pending" }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FeaturePageBackground()
                VStack(spacing: 0) {
                    if pendingSuggestions.isEmpty {
                        ContentUnavailableView(
                            "暂无待确认事项",
                            systemImage: "checkmark.seal.fill",
                            description: Text("所有 AI 生成的知识点与证据均已确认或已达到高置信度。")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("共有 \(pendingSuggestions.count) 条待确认建议")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("全部批准", systemImage: "checkmark.circle.fill") {
                                        appState.approveAllPendingSuggestions()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(AscendTheme.jade)
                                }
                                .padding(.horizontal, 4)

                                ForEach(pendingSuggestions) { suggestion in
                                    suggestionCard(for: suggestion)
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: 800)
                        }
                    }
                }
            }
            .navigationTitle("知识与证据审核")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成", action: { dismiss() })
                }
            }
        }
        .frame(minWidth: 580, idealWidth: 680, minHeight: 480, idealHeight: 600)
    }

    private func badgeTitle(for type: String) -> String {
        switch type {
        case "relation": "知识脉络建议"
        case "nextConcept": "下一境候选"
        case "newNode": "新知识点建议"
        default: "低置信度证据匹配"
        }
    }

    private func badgeIcon(for type: String) -> String {
        switch type {
        case "relation": "arrow.triangle.branch"
        case "nextConcept": "sparkles"
        case "newNode": "sparkle"
        default: "magnifyingglass"
        }
    }

    private func badgeColor(for type: String) -> Color {
        switch type {
        case "relation": AscendTheme.gold
        case "nextConcept": AscendTheme.jade
        case "newNode": AscendTheme.cobalt
        default: AscendTheme.amber
        }
    }

    @ViewBuilder
    private func suggestionCard(for suggestion: TaxonomySuggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    badgeTitle(for: suggestion.suggestionType),
                    systemImage: badgeIcon(for: suggestion.suggestionType)
                )
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(badgeColor(for: suggestion.suggestionType).opacity(0.18))
                .foregroundStyle(badgeColor(for: suggestion.suggestionType))
                .clipShape(.rect(cornerRadius: 6))

                if suggestion.suggestionType == "relation",
                   let sourceID = suggestion.sourceNodeID,
                   let targetID = suggestion.targetNodeID,
                   let source = appState.node(for: sourceID),
                   let target = appState.node(for: targetID) {
                    let rel = KnowledgeRelation.from(rawValue: suggestion.relationRawValue ?? "prerequisite")
                    Text("\(source.name) → \(rel.title) → \(target.name)")
                        .font(.headline)
                } else {
                    Text(suggestion.proposedName)
                        .font(.headline)
                }

                Spacer()

                Text("置信度 \(Int((suggestion.confidence * 100).rounded()))%")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            if !suggestion.rationale.isEmpty {
                Text(suggestion.rationale)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if suggestion.suggestionType == "reviewEvidence", let unverified = appState.evidence(for: suggestion) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text(unverified.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(8)
                .background(Color.primary.opacity(0.04))
                .clipShape(.rect(cornerRadius: 8))
            }

            Divider()

            if mergingSuggestionID == suggestion.id {
                VStack(alignment: .leading, spacing: 10) {
                    Text("选择要合并到的目标知识点：")
                        .font(.caption.bold())

                    let validTargets = appState.knowledgeNodes.filter { $0.id != suggestion.relatedNodeID }
                    if validTargets.isEmpty {
                        Text("暂无其他可选知识点")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("目标知识点", selection: $selectedMergeTargetID) {
                            Text("请选择…").tag(nil as UUID?)
                            ForEach(validTargets) { node in
                                Text("\(node.name) (\(node.domain))").tag(node.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)

                        HStack {
                            Button("确认合并") {
                                if let targetID = selectedMergeTargetID {
                                    appState.mergeSuggestion(suggestion, into: targetID)
                                    mergingSuggestionID = nil
                                    selectedMergeTargetID = nil
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AscendTheme.cobalt)
                            .disabled(selectedMergeTargetID == nil)

                            Button("取消", role: .cancel) {
                                mergingSuggestionID = nil
                                selectedMergeTargetID = nil
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(10)
                .background(AscendTheme.cobalt.opacity(0.06))
                .clipShape(.rect(cornerRadius: 8))
            } else if suggestion.suggestionType == "relation" {
                HStack(spacing: 12) {
                    Button("确认关系", systemImage: "checkmark") {
                        appState.approveSuggestion(suggestion)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AscendTheme.jade)

                    Spacer()

                    Button("舍弃", systemImage: "xmark", role: .destructive) {
                        appState.rejectSuggestion(suggestion)
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                }
                .font(.callout)
            } else if suggestion.suggestionType == "nextConcept" {
                HStack(spacing: 12) {
                    Button("收录该知识点", systemImage: "sparkles") {
                        appState.approveSuggestion(suggestion)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AscendTheme.jade)

                    Spacer()

                    Button("舍弃", systemImage: "xmark", role: .destructive) {
                        appState.rejectSuggestion(suggestion)
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                }
                .font(.callout)
            } else {
                HStack(spacing: 12) {
                    Button(suggestion.suggestionType == "newNode" ? "收录该知识点" : "确认该证据", systemImage: "checkmark") {
                        appState.approveSuggestion(suggestion)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AscendTheme.jade)

                    Button("合并至既有知识点…", systemImage: "arrow.triangle.merge") {
                        mergingSuggestionID = suggestion.id
                        selectedMergeTargetID = nil
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("舍弃", systemImage: "xmark", role: .destructive) {
                        appState.rejectSuggestion(suggestion)
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                }
                .font(.callout)
            }
        }
        .padding(16)
        .panelCard()
    }
}
