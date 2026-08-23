import Foundation

enum VisualTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case contemporary
    case xuanqing

    var id: Self { self }

    static let defaultTheme: Self = .xuanqing

    var title: String {
        switch self {
        case .contemporary: "清简"
        case .xuanqing: "玄青"
        }
    }

    var description: String {
        switch self {
        case .contemporary: "清晰克制的现代界面"
        case .xuanqing: "玄青、宣纸与朱砂构成的道家古风"
        }
    }
}
