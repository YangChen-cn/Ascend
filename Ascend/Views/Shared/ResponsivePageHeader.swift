import SwiftUI

struct ResponsivePageHeader<Header: View, Actions: View>: View {
    @ViewBuilder let header: Header
    @ViewBuilder let actions: Actions

    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder actions: () -> Actions
    ) {
        self.header = header()
        self.actions = actions()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                header
                    .layoutPriority(1)
                actions
                    .fixedSize()
            }

            VStack(alignment: .leading, spacing: 10) {
                header
                ScrollView(.horizontal) {
                    actions
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}
