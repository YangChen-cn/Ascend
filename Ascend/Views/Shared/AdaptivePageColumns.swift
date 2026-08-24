import SwiftUI

enum AdaptivePageColumnMode: Sendable, Equatable {
    case single
    case split
}

enum AdaptivePageLayoutPolicy {
    static let minimumPrimaryWidth: CGFloat = 540
    static let supplementaryWidth: CGFloat = 300
    static let spacing: CGFloat = 16

    static func columnMode(availableWidth: CGFloat, hasSupplementaryContent: Bool = true) -> AdaptivePageColumnMode {
        guard hasSupplementaryContent else { return .single }
        let required = minimumPrimaryWidth + supplementaryWidth + spacing
        return availableWidth >= required ? .split : .single
    }
}

private struct AdaptiveColumnsLayout: Layout {
    let supplementaryWidth: CGFloat
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let availableWidth = proposal.width ?? AdaptivePageLayoutPolicy.minimumPrimaryWidth
        let mode = AdaptivePageLayoutPolicy.columnMode(availableWidth: availableWidth)

        if mode == .split {
            let primaryWidth = max(0, availableWidth - supplementaryWidth - spacing)
            let primary = subviews[0].sizeThatFits(.init(width: primaryWidth, height: proposal.height))
            let supplementary = subviews[1].sizeThatFits(.init(width: supplementaryWidth, height: proposal.height))
            return CGSize(width: availableWidth, height: max(primary.height, supplementary.height))
        }

        let primary = subviews[0].sizeThatFits(.init(width: availableWidth, height: proposal.height))
        let supplementary = subviews[1].sizeThatFits(.init(width: availableWidth, height: proposal.height))
        return CGSize(width: availableWidth, height: primary.height + spacing + supplementary.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }
        let mode = AdaptivePageLayoutPolicy.columnMode(availableWidth: bounds.width)

        if mode == .split {
            let primaryWidth = max(0, bounds.width - supplementaryWidth - spacing)
            subviews[0].place(
                at: bounds.origin,
                anchor: .topLeading,
                proposal: .init(width: primaryWidth, height: proposal.height)
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX + primaryWidth + spacing, y: bounds.minY),
                anchor: .topLeading,
                proposal: .init(width: supplementaryWidth, height: proposal.height)
            )
        } else {
            let primarySize = subviews[0].sizeThatFits(.init(width: bounds.width, height: proposal.height))
            subviews[0].place(
                at: bounds.origin,
                anchor: .topLeading,
                proposal: .init(width: bounds.width, height: proposal.height)
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + primarySize.height + spacing),
                anchor: .topLeading,
                proposal: .init(width: bounds.width, height: proposal.height)
            )
        }
    }
}

struct AdaptivePageColumns<Primary: View, Supplementary: View>: View {
    @ViewBuilder let primary: Primary
    @ViewBuilder let supplementary: Supplementary

    init(
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder supplementary: () -> Supplementary
    ) {
        self.primary = primary()
        self.supplementary = supplementary()
    }

    var body: some View {
        AdaptiveColumnsLayout(
            supplementaryWidth: AdaptivePageLayoutPolicy.supplementaryWidth,
            spacing: AdaptivePageLayoutPolicy.spacing
        ) {
            primary
                .frame(maxWidth: .infinity, alignment: .topLeading)
            supplementary
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
