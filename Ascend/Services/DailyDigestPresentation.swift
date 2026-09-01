import Foundation

/// 将日报的兼容文本拆成稳定的展示字段，避免页面直接呈现一整段机器汇总文本。
struct DailyDigestPresentation: Equatable, Sendable {
    let learningSummary: String?
    let strongestGrowth: String?
    let xpSummary: String?
    let reviewSummary: String?
    let challengeSummary: String?
    let nextStep: String?

    init(summary: String) {
        let sections = summary
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        learningSummary = Self.value(after: "今日所学：", in: sections)
        strongestGrowth = Self.value(after: "最重要成长：", in: sections)
        xpSummary = Self.value(after: "真实知识 XP：", in: sections)
        reviewSummary = Self.value(after: "待复习：", in: sections)
        challengeSummary = Self.value(after: "完成挑战：", in: sections)
        nextStep = Self.value(after: "下一步推荐：", in: sections)
    }

    var primaryText: String {
        learningSummary ?? "今日尚无已验证学习结果；完成分析后，这里会收拢今日所得。"
    }

    private static func value(after prefix: String, in sections: [String]) -> String? {
        guard let section = sections.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        let value = String(section.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
