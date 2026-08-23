import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Binding var selection: NavigationSection
    @State private var isReviewSheetPresented = false

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(NavigationSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                        .accessibilityHint("打开\(section.title)")
                }
            }

            Section("成长") {
                if let leadingDomain = appState.domainProgress.first, appState.totalXP > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("总等级 Lv. \(appState.learnerLevel)")
                            .font(.headline)
                        Label("\(leadingDomain.name) · \(leadingDomain.realm.title)", systemImage: "mountain.2")
                            .foregroundStyle(AscendTheme.jade)
                        ProgressView(value: leadingDomain.xpProgress)
                            .tint(AscendTheme.jade)
                        Text("全领域 \(appState.totalXP.formatted()) XP")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    Label("尚无成长记录", systemImage: "sparkles")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("知境录")
        .safeAreaInset(edge: .bottom) {
            HStack {
                Image(systemName: appState.isCollecting ? "arrow.triangle.2.circlepath" : "pause.circle")
                Text(appState.isCollecting ? "正在采集" : "采集已暂停")
                Spacer()
                if appState.pendingReviewCount > 0 {
                    Button(action: { isReviewSheetPresented = true }) {
                        HStack(spacing: 4) {
                            Text("待确认")
                            Text("\(appState.pendingReviewCount)")
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(AscendTheme.amber.opacity(0.20))
                                .clipShape(.capsule)
                        }
                        .foregroundStyle(AscendTheme.amber)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.callout)
            .padding()
        }
        .sheet(isPresented: $isReviewSheetPresented) {
            TaxonomyReviewSheet()
        }
    }
}
