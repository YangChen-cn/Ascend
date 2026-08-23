import SwiftUI

struct DomainManagementSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDomain: String?
    @State private var renameText = ""
    @State private var mergeTarget = ""
    @State private var message: String?
    @State private var showsMergeConfirmation = false
    @State private var showsDeleteConfirmation = false

    let initialDomain: String?

    init(initialDomain: String? = nil) {
        self.initialDomain = initialDomain
        _selectedDomain = State(initialValue: initialDomain)
        _renameText = State(initialValue: initialDomain ?? "")
    }

    private var mergeCandidates: [String] {
        appState.domainNames.filter { name in
            guard let selectedDomain else { return true }
            return name.localizedStandardCompare(selectedDomain) != .orderedSame
        }
    }

    var body: some View {
        NavigationSplitView {
            List(appState.domainNames, id: \.self, selection: $selectedDomain) { domain in
                HStack {
                    Label(domain, systemImage: "sparkles")
                    Spacer()
                    Text(appState.nodes(inDomain: domain).count.formatted())
                        .foregroundStyle(.secondary)
                }
                .tag(domain)
            }
            .navigationTitle("领域")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240)
        } detail: {
            if let selectedDomain {
                Form {
                    Section("领域概览") {
                        LabeledContent("名称", value: selectedDomain)
                        LabeledContent("知识点", value: appState.nodes(inDomain: selectedDomain).count.formatted())
                    }

                    Section("重命名") {
                        TextField("新领域名称", text: $renameText)
                        Button("重命名领域", systemImage: "pencil", action: renameDomain)
                            .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Section("合并") {
                        Picker("目标领域", selection: $mergeTarget) {
                            Text("请选择目标领域").tag("")
                            ForEach(mergeCandidates, id: \.self) { domain in
                                Text(domain).tag(domain)
                            }
                        }
                        Button("合并至目标领域", systemImage: "arrow.triangle.merge") {
                            showsMergeConfirmation = true
                        }
                            .disabled(mergeTarget.isEmpty)
                            .confirmationDialog(
                                "将“\(selectedDomain)”合并至“\(mergeTarget)”？",
                                isPresented: $showsMergeConfirmation
                            ) {
                                Button("确认合并") {
                                    mergeDomain()
                                }
                                Button("取消", role: .cancel) {}
                            } message: {
                                Text("源领域的全部知识点会归入目标领域，证据、掌握度、XP 和关系保持不变；合并后不会自动拆分。")
                            }
                        Text("知识点、证据、掌握度与 XP 都会保留，并改归目标领域。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Section("删除") {
                        Button("删除领域…", systemImage: "trash", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                        .confirmationDialog(
                            "如何删除领域“\(selectedDomain)”？",
                            isPresented: $showsDeleteConfirmation
                        ) {
                            if selectedDomain.localizedStandardCompare("待分类") != .orderedSame {
                                Button("保留知识点并移至“待分类”") {
                                    deleteDomain(strategy: .moveKnowledgeToUncategorized)
                                }
                            }
                            Button("连同知识点永久删除", role: .destructive) {
                                deleteDomain(strategy: .deleteKnowledge)
                            }
                        } message: {
                            Text("永久删除会同时移除该领域的知识点、证据、评分、XP、关系和关联挑战，且无法撤销。")
                        }
                    }

                    if let message {
                        Section {
                            Text(message)
                                .foregroundStyle(message.hasPrefix("已") ? AscendTheme.jade : .red)
                        }
                    }
                }
                .formStyle(.grouped)
                .navigationTitle(selectedDomain)
            } else {
                ContentUnavailableView("暂无领域", systemImage: "sparkles")
            }
        }
        .frame(minWidth: 760, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成", action: dismiss.callAsFunction)
            }
        }
        .onAppear(perform: selectInitialDomain)
        .onChange(of: selectedDomain, updateEditingState)
        .onChange(of: appState.domainNames) { _, domains in
            if selectedDomain.map(domains.contains) != true {
                selectedDomain = domains.first
            }
        }
    }

    private func selectInitialDomain() {
        if let initialDomain, appState.domainNames.contains(initialDomain) {
            selectedDomain = initialDomain
        } else if selectedDomain == nil {
            selectedDomain = appState.domainNames.first
        }
        updateEditingState(nil, selectedDomain)
    }

    private func updateEditingState(_ oldValue: String?, _ newValue: String?) {
        guard oldValue != newValue else { return }
        renameText = newValue ?? ""
        mergeTarget = ""
        message = nil
    }

    private func renameDomain() {
        guard let selectedDomain else { return }
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try appState.renameDomain(selectedDomain, to: newName)
            self.selectedDomain = newName
            message = "已完成重命名"
        } catch {
            message = error.localizedDescription
        }
    }

    private func mergeDomain() {
        guard let selectedDomain, !mergeTarget.isEmpty else { return }
        do {
            let target = mergeTarget
            try appState.mergeDomain(selectedDomain, into: target)
            self.selectedDomain = target
            message = "已完成领域合并"
        } catch {
            message = error.localizedDescription
        }
    }

    private func deleteDomain(strategy: DomainDeletionStrategy) {
        guard let selectedDomain else { return }
        do {
            try appState.deleteDomain(selectedDomain, strategy: strategy)
            self.selectedDomain = strategy == .moveKnowledgeToUncategorized
                ? "待分类"
                : appState.domainNames.first
            message = "已删除领域"
        } catch {
            message = error.localizedDescription
        }
    }
}
