import SwiftUI

struct MasteryDimensionStrip: View {
    let vector: MasteryVector
    var foundationVector: MasteryVector? = nil
    var verificationTitle: String? = nil

    private var dimensions: [(String, String, Double)] {
        [
            ("接触", "eye", vector.exposure),
            ("理解", "lightbulb", vector.understanding),
            ("实践", "chevron.left.forwardslash.chevron.right", vector.practice),
            ("记忆", "arrow.clockwise", vector.retention),
            ("自主", "target", vector.autonomy)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                SectionTitleView("掌握构成")
                if let foundationVector {
                    Text("资料基础 \(Int(foundationVector.composite.rounded()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let verificationTitle {
                    Text("验证：\(verificationTitle)")
                        .font(.caption)
                        .foregroundStyle(AscendTheme.jade)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 20)], alignment: .leading, spacing: 18) {
                ForEach(dimensions, id: \.0) { dimension in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(dimension.0, systemImage: dimension.1)
                            .font(.callout)
                        ProgressView(value: dimension.2, total: 100)
                            .tint(AscendTheme.jade)
                        Text(levelTitle(for: dimension.2))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help("\(dimension.0)：\(Int(dimension.2.rounded()))")
                }
            }
        }
    }

    /// 外部只呈现三档语义，精确分数留在 tooltip；内部复杂度不给用户制造五套数字
    private func levelTitle(for score: Double) -> String {
        switch score {
        case ..<20: "刚接触"
        case ..<45: "在成长"
        case ..<70: "较扎实"
        default: "很扎实"
        }
    }
}
