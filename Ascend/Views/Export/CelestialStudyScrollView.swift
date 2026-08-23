import SwiftUI

struct CelestialStudyScrollView: View {
    @Environment(AppState.self) private var appState
    var isDark: Bool = true
    var date: Date = .now

    private var averageVector: MasteryVector {
        guard !appState.masteryStates.isEmpty else {
            return MasteryVector.zero
        }
        let count = Double(appState.masteryStates.count)
        let totalExposure = appState.masteryStates.reduce(0.0) { $0 + $1.vector.exposure }
        let totalUnderstanding = appState.masteryStates.reduce(0.0) { $0 + $1.vector.understanding }
        let totalPractice = appState.masteryStates.reduce(0.0) { $0 + $1.vector.practice }
        let totalRetention = appState.masteryStates.reduce(0.0) { $0 + $1.vector.retention }
        let totalAutonomy = appState.masteryStates.reduce(0.0) { $0 + $1.vector.autonomy }
        return MasteryVector(
            exposure: totalExposure / count,
            understanding: totalUnderstanding / count,
            practice: totalPractice / count,
            retention: totalRetention / count,
            autonomy: totalAutonomy / count
        ).clamped()
    }

    private var leadingDomain: DomainProgressSnapshot? {
        appState.domainProgress.first
    }

    private var recentEvidence: [EvidenceRecord] {
        Array(appState.evidenceRecords.sorted(by: { $0.timestamp > $1.timestamp }).prefix(3))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 卷轴顶部装潢轴杆
            scrollRod(isTop: true)

            // 画卷正文主体
            VStack(alignment: .leading, spacing: 22) {
                // 1. 卷首印章与抬头
                headerSection

                Divider()
                    .overlay(AscendTheme.gold.opacity(0.35))

                // 2. 主修道行与修真境界标头
                mainRealSection

                // 3. 五维全真雷达图 与 诸天灵根分布
                masteryAndDomainsSection

                // 4. 近期悟道与实据精进
                recentInsightsSection

                // 5. 卷尾真言、防伪印章与远山水墨画卷
                footerSection
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 28)
            .background(scrollPaperBackground)
            .overlay {
                // 古典外围金丝双边框
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                AscendTheme.gold.opacity(0.40),
                                AscendTheme.jade.opacity(0.30),
                                AscendTheme.gold.opacity(0.40)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .padding(8)
            }

            // 卷轴底部装潢轴杆
            scrollRod(isTop: false)
        }
        .frame(width: 680)
    }

    // MARK: - 卷轴纸质底色

    private var scrollPaperBackground: some View {
        ZStack {
            if isDark {
                Color(red: 0.040, green: 0.060, blue: 0.070)
                RadialGradient(
                    colors: [Color(red: 0.08, green: 0.12, blue: 0.14).opacity(0.6), Color.clear],
                    center: .center,
                    startRadius: 50,
                    endRadius: 400
                )
            } else {
                Color(red: 0.985, green: 0.975, blue: 0.945) // 羊脂宣纸底
                RadialGradient(
                    colors: [Color(red: 0.93, green: 0.90, blue: 0.82).opacity(0.4), Color.clear],
                    center: .center,
                    startRadius: 50,
                    endRadius: 400
                )
            }
        }
    }

    // MARK: - 卷首印章与抬头

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("知境录")
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundStyle(isDark ? Color.white : Color.black)

                    Text("· 修真研习画卷")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundStyle(AscendTheme.gold)
                }

                Text("以实据为阶 · 见真知灼见")
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 古典修历时间玉符
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Text("实据研习册")
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .foregroundStyle(AscendTheme.amber)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AscendTheme.amber.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                    Text(lunarDateString(for: date))
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundStyle(isDark ? Color.white.opacity(0.9) : Color.black.opacity(0.85))
                }

                Text(date, format: .dateTime.year().month().day().hour().minute())
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 主修道行与修真境界

    private var mainRealSection: some View {
        HStack(alignment: .center, spacing: 20) {
            // 左侧：道行等级令牌
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AscendTheme.goldGradient)
                        .frame(width: 48, height: 48)
                        .shadow(color: AscendTheme.gold.opacity(0.4), radius: 6)

                    Image(systemName: "flame.fill")
                        .font(.title3)
                        .foregroundStyle(Color.black)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("道行修位")
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(.secondary)
                    Text("Lv.\(appState.learnerLevel)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(AscendTheme.gold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(AscendTheme.gold.opacity(0.25), lineWidth: 0.8)
            }

            Spacer()

            // 中间：总知验
            VStack(alignment: .trailing, spacing: 2) {
                Text("累积知验")
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(.secondary)
                Text("\(appState.totalXP.formatted()) XP")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AscendTheme.gold)
            }

            // 右侧：首席灵根境界印章
            if let leading = leadingDomain {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("首席灵根 · \(leading.name)")
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(.secondary)

                    CelestialBadge(
                        title: leading.realm.title,
                        subtitle: "\(Int(leading.currentScore.rounded())) 分",
                        systemImage: "seal.fill",
                        style: .gold
                    )
                }
            }
        }
    }

    // MARK: - 五维雷达与诸天灵根

    private var masteryAndDomainsSection: some View {
        HStack(alignment: .top, spacing: 24) {
            // 五维全真雷达图
            VStack(alignment: .center, spacing: 8) {
                Text("全真五维掌握图")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(isDark ? Color.white.opacity(0.9) : Color.primary)

                MasteryRadarChartView(
                    vector: averageVector,
                    isDark: isDark,
                    size: 180
                )
                .padding(.vertical, 4)

                Text("接触 10% · 理解 25% · 实践 25% · 记忆 20% · 自主 20%")
                    .font(.system(size: 8.5, design: .serif))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.02))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.8)
            }

            // 诸天领域（灵根）榜
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("诸天灵根成长榜")
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundStyle(isDark ? Color.white.opacity(0.9) : Color.primary)
                    Spacer()
                    Text("共 \(appState.domainProgress.count) 域 · \(appState.knowledgeNodes.count) 知窍")
                        .font(.system(size: 10, design: .serif))
                        .foregroundStyle(.secondary)
                }

                if appState.domainProgress.isEmpty {
                    Text("初入道途 · 虚位以待")
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 8) {
                        ForEach(appState.domainProgress.prefix(4)) { domain in
                            domainScrollRow(domain: domain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.02))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.8)
            }
        }
    }

    private func domainScrollRow(domain: DomainProgressSnapshot) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(domain.name)
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(isDark ? Color.white : Color.primary)
                Spacer()
                Text("\(domain.xp) XP")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(AscendTheme.gold)

                CelestialBadge(
                    title: domain.realm.title,
                    style: domain.currentScore >= 60 ? .gold : .jade
                )
                .scaleEffect(0.85)
            }

            // 掌握度进度条
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                        .frame(height: 4)
                    Capsule()
                        .fill(AscendTheme.jadeGradient)
                        .frame(width: max(3, proxy.size.width * CGFloat(min(1.0, domain.currentScore / 100.0))), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 2)
    }

    // MARK: - 近期悟道与实据精进

    private var recentInsightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(AscendTheme.gold)
                Text("最新研习与精进实据")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(isDark ? Color.white.opacity(0.9) : Color.primary)
                Spacer()
                Text("真实可溯 · 拒绝虚浮")
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(.secondary)
            }

            if recentEvidence.isEmpty {
                Text("连接本地 Git 仓库或 Markdown 笔记后，真实研习实据将在此凝练记录。")
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 6) {
                    ForEach(recentEvidence) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(AscendTheme.jade)
                                .frame(width: 5, height: 5)
                            Text(item.summary)
                                .font(.system(size: 11, design: .serif))
                                .foregroundStyle(isDark ? Color.white.opacity(0.85) : Color.black.opacity(0.85))
                                .lineLimit(1)
                            Spacer()
                            Text(item.timestamp, format: .dateTime.month().day())
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.02))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.8)
        }
    }

    // MARK: - 卷尾水墨远山与真言印章

    private var footerSection: some View {
        VStack(spacing: 12) {
            // 水墨远山
            InkLandscapeWatermark(height: 60, opacity: isDark ? 0.35 : 0.25)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("知境录 · 本地优先个人成长系统")
                        .font(.system(size: 9.5, design: .serif))
                        .foregroundStyle(.secondary)
                    Text("修学历程真实可溯，知识境界循证而立。")
                        .font(.system(size: 8.5, design: .serif))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // 古典朱砂印章
                HStack(spacing: 4) {
                    Image(systemName: "seal.fill")
                        .font(.caption2)
                    Text("以据求道")
                        .font(.system(size: 10, weight: .heavy, design: .serif))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AscendTheme.amber.opacity(0.15))
                .foregroundStyle(AscendTheme.amber)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(AscendTheme.amber.opacity(0.4), lineWidth: 0.8)
                }
            }
        }
    }

    // MARK: - 轴杆装潢

    private func scrollRod(isTop: Bool) -> some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.28, green: 0.20, blue: 0.12),
                            Color(red: 0.50, green: 0.38, blue: 0.24),
                            Color(red: 0.28, green: 0.20, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 12)

            // 两端金箍
            HStack {
                Capsule()
                    .fill(AscendTheme.goldGradient)
                    .frame(width: 24, height: 14)
                Spacer()
                Capsule()
                    .fill(AscendTheme.goldGradient)
                    .frame(width: 24, height: 14)
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 14)
        .padding(.horizontal, -8)
    }

    private func lunarDateString(for date: Date) -> String {
        let calendar = Calendar(identifier: .chinese)
        let year = calendar.component(.year, from: date)

        let heavenlyStems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
        let earthlyBranches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]

        let stem = heavenlyStems[(year - 1) % 10]
        let branch = earthlyBranches[(year - 1) % 12]

        return "\(stem)\(branch)年 · 研习实据卷"
    }
}
