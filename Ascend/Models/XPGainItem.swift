import Foundation

struct XPGainItem: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let systemImage: String
    let xp: Int
}
