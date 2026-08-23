import SwiftUI

struct MasteryRingView: View {
    let score: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 8)
            Circle()
                .trim(from: 0, to: score / 100)
                .stroke(AscendTheme.jade, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(Int(score.rounded()).formatted())
                    .font(.system(.largeTitle, design: .rounded))
                    .bold()
                Text("掌握")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 145, height: 145)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("掌握 \(Int(score.rounded()))")
    }
}
