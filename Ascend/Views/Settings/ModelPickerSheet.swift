import SwiftUI

struct ModelPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let models: [RemoteModel]
    let selectedModelID: String
    let onSelect: (String) -> Void
    @State private var searchText = ""

    private var filteredModels: [RemoteModel] {
        guard !searchText.isEmpty else { return models }
        return models.filter { $0.id.localizedStandardContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择模型").font(.title2).bold()
            Text("接口返回 \(models.count) 个模型。列表不保证每个模型都支持文本对话，可在选择后使用“测试所选模型”。")
                .foregroundStyle(.secondary)
            List(filteredModels) { model in
                Button(action: { onSelect(model.id) }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(model.id)
                            if let ownedBy = model.ownedBy {
                                Text(ownedBy).font(.callout).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if model.id == selectedModelID {
                            Image(systemName: "checkmark").foregroundStyle(AscendTheme.jade)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "搜索模型 ID")
            HStack {
                Spacer()
                Button("取消", action: dismiss.callAsFunction)
            }
        }
        .padding(22)
        .frame(width: 560, height: 520)
    }
}
