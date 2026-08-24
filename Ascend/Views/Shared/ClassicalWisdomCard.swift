import SwiftUI

struct ClassicalWisdomQuote: Identifiable, Sendable {
    let id: Int
    let text: String
    let author: String
    let source: String
    let sealText: String
}

/// 「文心雅鉴 · 修身求真治学卡」
/// 精选中国传统修身、治学与知行合一经典名句，配以宣纸暗纹、金石印章与水墨底蕴。
/// 当页面卡片内容较少或窗口放大留白较多时，优雅填充视觉空间，增添古典东方书院沉浸感。
struct ClassicalWisdomCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentIndex: Int = 0

    private static let quotes: [ClassicalWisdomQuote] = [
        ClassicalWisdomQuote(
            id: 0,
            text: "博学之，审问之，慎思之，明辨之，笃行之。有弗学，学之弗能弗措也。",
            author: "子思",
            source: "《礼记·中庸》",
            sealText: "笃行"
        ),
        ClassicalWisdomQuote(
            id: 1,
            text: "知是行之始，行是知之成。圣学只一个功夫，知行不可分作两事。",
            author: "王阳明",
            source: "《传习录》",
            sealText: "知行"
        ),
        ClassicalWisdomQuote(
            id: 2,
            text: "不积跬步，无以至千里；不积小流，无以成江海。驽马十驾，功在不舍。",
            author: "荀子",
            source: "《荀子·劝学》",
            sealText: "不舍"
        ),
        ClassicalWisdomQuote(
            id: 3,
            text: "合抱之木，生于毫末；九层之台，起于累土；千里之行，始于足下。",
            author: "老子",
            source: "《道德经》",
            sealText: "毫末"
        ),
        ClassicalWisdomQuote(
            id: 4,
            text: "纸上得来终觉浅，绝知此事要躬行。少壮工夫老始成，古人学问无遗力。",
            author: "陆游",
            source: "《冬夜读书示子聿》",
            sealText: "躬行"
        ),
        ClassicalWisdomQuote(
            id: 5,
            text: "今日格一件，明日格一件，积习既多，然后脱然自有贯通处。",
            author: "朱熹",
            source: "《朱子语类》",
            sealText: "贯通"
        ),
        ClassicalWisdomQuote(
            id: 6,
            text: "吾生也有涯，而知也无涯。顺应自然，游刃有余，方见大道真传。",
            author: "庄子",
            source: "《庄子·养生主》",
            sealText: "真常"
        ),
        ClassicalWisdomQuote(
            id: 7,
            text: "天行健，君子以自强不息；地势坤，君子以厚德载物。",
            author: "周文王",
            source: "《周易·乾坤》",
            sealText: "自强"
        )
    ]

    var body: some View {
        let quote = Self.quotes[currentIndex % Self.quotes.count]

        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentIndex = (currentIndex + 1) % Self.quotes.count
            }
        } label: {
            HStack(alignment: .top, spacing: 16) {
                // 左侧古典书卷印记
                ZStack {
                    Circle()
                        .fill(AscendTheme.gold.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "scroll.fill")
                        .font(.title3)
                        .foregroundStyle(AscendTheme.gold)
                }
                .padding(.top, 2)

                // 中部经典名句
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("文心雅鉴 · 修身治学")
                            .font(.system(.subheadline, design: .serif))
                            .bold()
                            .foregroundStyle(AscendTheme.gold)

                        Text("· 轻触换篇")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text("“\(quote.text)”")
                        .font(.system(.body, design: .serif))
                        .lineSpacing(4)
                        .foregroundStyle(Color.primary.opacity(0.90))

                    HStack(spacing: 6) {
                        Text("—— \(quote.author) · \(quote.source)")
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 右侧朱砂法印
                ClassicalSealMark(
                    text: quote.sealText,
                    shape: .square,
                    style: .cinnabar,
                    carving: .intaglio,
                    size: 24
                )
                .padding(.top, 4)
            }
            .panelCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("修身治学古训：\(quote.text)")
        .accessibilityHint("点击切换下一条古训名句")
        .onAppear {
            // 每次出现随机或按日选一条
            let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
            currentIndex = day % Self.quotes.count
        }
    }
}
