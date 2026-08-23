import SwiftUI

struct SectionTitleView: View {
    let title: String
    var systemImage: String?

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
                .font(.title3)
                .bold()
        } else {
            Text(title)
                .font(.title3)
                .bold()
        }
    }
}
