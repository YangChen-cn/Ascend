import SwiftUI

struct AIEndpointsSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedProfileID: UUID?
    @State private var draft = EndpointDraft()
    @State private var modelSelection: ModelSelectionContext?
    @State private var isConnecting = false
    @State private var isTesting = false
    @State private var message: String?

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("AI 接口").font(.title2).bold()
                    Spacer()
                    Button("添加接口", systemImage: "plus", action: addEndpoint)
                        .labelStyle(.iconOnly)
                }
                List(appState.endpointProfiles, selection: $selectedProfileID) { profile in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                        Text(profile.selectedModelID.isEmpty ? "未选择模型" : profile.selectedModelID)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(profile.id)
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 210, idealWidth: 230)
            .padding(.trailing, 10)

            Form {
                Section("接口档案") {
                    TextField("名称", text: $draft.name)
                    TextField("Base URL", text: $draft.baseURLString)
                        .textContentType(.URL)
                    SecureField("API Key（留空保持原密钥）", text: $draft.apiKey)
                    Toggle("启用", isOn: $draft.isEnabled)
                }
                Section("模型") {
                    TextField("模型 ID", text: $draft.selectedModelID)
                    HStack {
                        Button(isConnecting ? "正在连接…" : "连接并获取模型", systemImage: "arrow.triangle.2.circlepath", action: connect)
                            .disabled(isConnecting)
                        Button(isTesting ? "正在测试…" : "测试所选模型", systemImage: "checkmark.circle", action: testModel)
                            .disabled(isTesting || draft.selectedModelID.isEmpty)
                    }
                    Text("连接会调用 Base URL 下的 /models，并弹出接口返回的全部模型。若接口不支持列表，可直接填写模型 ID。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Section {
                    HStack {
                        Button("保存", systemImage: "square.and.arrow.down", action: save)
                            .buttonStyle(.borderedProminent)
                        if selectedProfileID != nil {
                            Button("删除", systemImage: "trash", role: .destructive, action: delete)
                        }
                    }
                }
                if let message {
                    Section { Text(message).foregroundStyle(message.hasPrefix("成功") ? AscendTheme.jade : .red) }
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 500)
        }
        .onChange(of: selectedProfileID, loadSelectedProfile)
        .sheet(item: $modelSelection) { context in
            ModelPickerSheet(models: context.models, selectedModelID: draft.selectedModelID, onSelect: selectModel)
        }
        .task {
            if selectedProfileID == nil, let first = appState.endpointProfiles.first {
                selectedProfileID = first.id
                draft = appState.draft(for: first)
            }
        }
    }

    private func addEndpoint() {
        selectedProfileID = nil
        draft = EndpointDraft()
        message = nil
    }

    private func loadSelectedProfile(_ oldValue: UUID?, _ newValue: UUID?) {
        guard oldValue != newValue else { return }
        draft = appState.draft(for: appState.endpointProfiles.first { $0.id == newValue })
        message = nil
    }

    private func connect() {
        isConnecting = true
        message = nil
        Task {
            defer { isConnecting = false }
            do {
                let models = try await appState.connect(draft)
                draft.cachedModelIDs = models.map(\.id)
                modelSelection = ModelSelectionContext(endpointID: draft.id, models: models)
                message = "成功连接，发现 \(models.count) 个模型"
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func testModel() {
        isTesting = true
        message = nil
        Task {
            defer { isTesting = false }
            do {
                try await appState.test(draft)
                message = "成功：模型可以完成 Chat Completions 请求"
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func save() {
        Task {
            do {
                try await appState.saveEndpoint(draft)
                selectedProfileID = draft.id
                message = "成功保存；API Key 已写入本机 Keychain"
                draft.apiKey = ""
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func delete() {
        guard let profile = appState.endpointProfiles.first(where: { $0.id == selectedProfileID }) else { return }
        Task {
            do {
                try await appState.deleteEndpoint(profile)
                addEndpoint()
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func selectModel(_ modelID: String) {
        draft.selectedModelID = modelID
        modelSelection = nil
    }
}
