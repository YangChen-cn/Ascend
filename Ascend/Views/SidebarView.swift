import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Binding var selection: NavigationSection
    @State private var isReviewSheetPresented = false
    @State private var isExportSheetPresented = false

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(NavigationSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .font(.system(.body, design: .serif))
                        .tag(section)
                        .accessibilityHint("打开\(section.title)")
                }
            }

            Section("修真境界") {
                if let leadingDomain = appState.domainProgress.first, appState.totalXP > 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("道行 Lv.\(appState.learnerLevel)")
                                .font(.system(.headline, design: .serif))
                                .bold()
                            Spacer()
                            CelestialBadge(
                                title: leadingDomain.realm.title,
                                systemImage: "seal.fill",
                                style: .gold
                            )
                        }

                        Text("首席灵根 · \(leadingDomain.name)")
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(.secondary)

                        // 流金灵气进度条
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 5)
                                Capsule()
                                    .fill(AscendTheme.goldGradient)
                                    .frame(width: max(4, proxy.size.width * CGFloat(min(1.0, max(0.0, leadingDomain.xpProgress)))), height: 5)
                            }
                        }
                        .frame(height: 5)

                        HStack {
                            Text("总积知验")
                                .font(.system(.caption2, design: .serif))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(appState.totalXP.formatted()) XP")
                                .font(.system(.caption, design: .rounded))
                                .bold()
                                .foregroundStyle(AscendTheme.gold)
                        }

                        Divider()
                            .overlay(AscendTheme.gold.opacity(0.15))

                        Button(action: { isExportSheetPresented = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "scroll.fill")
                                    .font(.caption2)
                                    .foregroundStyle(AscendTheme.gold)
                                Text("导出研习画卷…")
                                    .font(.system(.caption, design: .serif))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AscendTheme.gold.opacity(0.20), lineWidth: 0.8)
                    }
                    .padding(.vertical, 6)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(AscendTheme.gold)
                        Text("初入道途 · 虚位以待")
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("知境录")
        .safeAreaInset(edge: .bottom) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.isCollecting ? AscendTheme.jade : AscendTheme.slate)
                        .frame(width: 8, height: 8)
                    Text(appState.isCollecting ? "巡察灵机中" : "巡察已歇")
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if appState.pendingReviewCount > 0 {
                    Button(action: { isReviewSheetPresented = true }) {
                        CelestialBadge(
                            title: "知识建议",
                            subtitle: "\(appState.pendingReviewCount)",
                            systemImage: "sparkle.magnifyingglass",
                            style: .neutral
                        )
                    }
                    .buttonStyle(.plain)
                    .help("\(appState.pendingReviewCount) 条知识归属建议可确认；不处理也不影响日常成长")
                }

                TargetedSettingsButton(section: .general) {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("打开设置 (⌘,)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .sheet(isPresented: $isReviewSheetPresented) {
            TaxonomyReviewSheet()
        }
        .sheet(isPresented: $isExportSheetPresented) {
            CelestialScrollExportSheet()
        }
    }
}
