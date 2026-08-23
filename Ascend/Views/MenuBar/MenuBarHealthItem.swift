import Foundation

struct MenuBarHealthItem: Identifiable {
    enum State {
        case healthy
        case inactive
        case warning
    }

    let id: String
    let title: String
    let status: String
    let state: State
    let detail: String?
}
