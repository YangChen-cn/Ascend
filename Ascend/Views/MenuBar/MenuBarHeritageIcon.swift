import SwiftUI

struct MenuBarHeritageIcon: View {
    let isActive: Bool

    var body: some View {
        Image("MenuBarHeritage")
            .resizable()
            .renderingMode(.template)
            .interpolation(.high)
            .foregroundStyle(.primary)
            .opacity(isActive ? 1 : 0.62)
        .frame(width: 18, height: 18)
    }
}
