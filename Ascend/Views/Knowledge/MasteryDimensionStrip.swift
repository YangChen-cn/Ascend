import SwiftUI

struct MasteryDimensionStrip: View {
    let vector: MasteryVector

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
            SectionTitleView("掌握")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 20)], alignment: .leading, spacing: 18) {
                ForEach(dimensions, id: \.0) { dimension in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(dimension.0, systemImage: dimension.1)
                        Text(Int(dimension.2.rounded()).formatted())
                            .font(.title2)
                            .bold()
                        ProgressView(value: dimension.2, total: 100)
                            .tint(AscendTheme.jade)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
