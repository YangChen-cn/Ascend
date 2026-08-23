import SwiftUI

struct ActiveModelMenu: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Menu("模型", systemImage: "cpu") {
            if appState.endpointProfiles.isEmpty {
                Text("请先在设置中添加 AI 接口")
            } else {
                ForEach(appState.endpointProfiles) { profile in
                    Section(profile.name) {
                        if profile.cachedModelIDs.isEmpty {
                            Button(profile.selectedModelID.isEmpty ? "未选择模型" : profile.selectedModelID) {
                                appState.setActiveEndpoint(profile.id)
                            }
                        } else {
                            ForEach(profile.cachedModelIDs, id: \.self) { modelID in
                                Button(modelID, action: { select(profileID: profile.id, modelID: modelID) })
                            }
                        }
                    }
                }
            }
            Divider()
            TargetedSettingsButton(section: .ai) {
                Label("管理 AI 接口…", systemImage: "gearshape")
            }
        }
        .help("切换全局默认接口和模型")
    }

    private func select(profileID: UUID, modelID: String) {
        appState.selectModel(profileID: profileID, modelID: modelID)
    }
}
