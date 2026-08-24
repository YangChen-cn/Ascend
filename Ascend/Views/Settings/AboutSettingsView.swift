import AppKit
import SwiftUI

struct AboutSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.9.9"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    private let repoURL = URL(string: "https://github.com/YangChen-cn/Ascend")!
    private let releasesURL = URL(string: "https://github.com/YangChen-cn/Ascend/releases")!

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 顶部品牌标识区
                VStack(spacing: 14) {
                    ZStack {
                        // 外层金玉光晕
                        Circle()
                            .fill(AscendTheme.gold.opacity(colorScheme == .dark ? 0.20 : 0.12))
                            .frame(width: 108, height: 108)
                            .blur(radius: 12)

                        // 应用图标本体
                        if let icon = NSApplication.shared.applicationIconImage {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 88, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(AscendTheme.gold.opacity(0.4), lineWidth: 1.2)
                                }
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.15), radius: 10, y: 4)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundStyle(AscendTheme.gold)
                        }
                    }

                    VStack(spacing: 4) {
                        Text("知 境 录")
                            .font(.system(.title, design: AscendTheme.titleDesign))
                            .bold()

                        Text("Ascend · 东方意境个人研习监控与境界成长系统")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            Text("版本 \(appVersion) (Build \(buildNumber))")
                                .font(.caption.monospaced())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2.5)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule().strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8)
                                }

                            Text("macOS 15.0+ · Apple 芯片优化")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }

                Divider()
                    .overlay(AscendTheme.gold.opacity(0.20))

                // 项目定位与核心心法
                VStack(alignment: .leading, spacing: 14) {
                    Text("系统心法")
                        .font(.system(.headline, design: AscendTheme.titleDesign))
                        .bold()

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        coreFeatureCard(
                            icon: "shield.lefthalf.filled",
                            title: "本地优先 · 实据定鼎",
                            desc: "只凭真实代码与笔记证据计分，API Key 仅存于 Keychain，数据不出本地。"
                        )
                        coreFeatureCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "五维心印 · 六重境界",
                            desc: "接触、理解、实践、记忆、自主五维评估，历经初窥至通达六重突破。"
                        )
                        coreFeatureCard(
                            icon: "point.3.connected.trianglepath.dotted",
                            title: "先导脉络 · 诸天星宿",
                            desc: "Concept Lineage 严格 DAG 先导依赖，前置达标自动解锁下一境修炼。"
                        )
                        coreFeatureCard(
                            icon: "brain.head.profile",
                            title: "FSRS 调度 · 科学抗遗忘",
                            desc: "实时预测记忆衰减可提取率，智能安排温故知新，遗忘不扣减历史成就。"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .overlay(AscendTheme.gold.opacity(0.20))

                // 作者与开源信息
                VStack(alignment: .leading, spacing: 12) {
                    Text("开源与贡献")
                        .font(.system(.headline, design: AscendTheme.titleDesign))
                        .bold()

                    VStack(spacing: 8) {
                        HStack {
                            Label("作者", systemImage: "person.circle.fill")
                                .font(.subheadline)
                            Spacer()
                            Text("YangChen")
                                .font(.system(.subheadline, design: .serif).bold())
                                .foregroundStyle(AscendTheme.gold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        HStack {
                            Label("开源仓库", systemImage: "link")
                                .font(.subheadline)
                            Spacer()
                            Button("YangChen-cn/Ascend") {
                                openURL(repoURL)
                            }
                            .buttonStyle(.link)
                            .font(.system(.subheadline, design: .monospaced))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        HStack {
                            Label("开源协议", systemImage: "doc.text.fill")
                                .font(.subheadline)
                            Spacer()
                            Text("MIT License")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    HStack(spacing: 12) {
                        Button(action: { openURL(repoURL) }) {
                            Label("访问 GitHub 仓库", systemImage: "safari")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AscendTheme.gold)

                        Button(action: { openURL(releasesURL) }) {
                            Label("查看版本发布 (Releases)", systemImage: "arrow.down.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
        }
    }

    private func coreFeatureCard(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(AscendTheme.gold)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8)
        }
    }
}
