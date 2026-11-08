import SwiftUI

/// Title, active leading/trailing actions, then noninteractive leading/trailing reservations.
struct StableHeaderLayout: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let metrics = metrics(for: subviews)
        let width = proposal.width ?? metrics.inlineWidth
        return CGSize(width: width, height: metrics.height(at: width, spacing: spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let metrics = metrics(for: subviews)
        let inline = bounds.width >= metrics.inlineWidth
        let titleY = inline ? max(metrics.title.height, metrics.side.height) / 2 : metrics.title.height / 2
        subviews[0].place(at: CGPoint(x: bounds.midX, y: bounds.minY + titleY),
                          anchor: .center, proposal: ProposedViewSize(metrics.title))

        let separateActionRows = bounds.width < metrics.actionWidth
        let firstActionY = inline ? titleY : metrics.title.height + spacing + metrics.side.height / 2
        let lastActionY = firstActionY + (inline || !separateActionRows ? 0 : metrics.side.height + spacing)
        // SwiftUI mirrors custom Layout coordinates in right-to-left environments.
        subviews[1].place(at: CGPoint(x: bounds.minX, y: bounds.minY + firstActionY),
                          anchor: UnitPoint(x: 0, y: 0.5),
                          proposal: ProposedViewSize(metrics.leading))
        subviews[2].place(at: CGPoint(x: bounds.maxX, y: bounds.minY + lastActionY),
                          anchor: UnitPoint(x: 1, y: 0.5),
                          proposal: ProposedViewSize(metrics.trailing))
        // The hidden measurement view participates in sizing only.
        subviews[3].place(at: bounds.origin, proposal: .zero)
        subviews[4].place(at: bounds.origin, proposal: .zero)
    }

    private func metrics(for subviews: Subviews) -> Metrics {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return Metrics(title: sizes[0], leading: sizes[1], trailing: sizes[2],
                       leadingReservation: sizes[3], trailingReservation: sizes[4], spacing: spacing)
    }

    private struct Metrics {
        let title: CGSize
        let leading: CGSize
        let trailing: CGSize
        let side: CGSize
        let inlineWidth: CGFloat
        let actionWidth: CGFloat

        init(title: CGSize, leading: CGSize, trailing: CGSize,
             leadingReservation: CGSize, trailingReservation: CGSize, spacing: CGFloat) {
            self.title = title
            self.leading = leading
            self.trailing = trailing
            let leadingWidth = max(leading.width, leadingReservation.width)
            let trailingWidth = max(trailing.width, trailingReservation.width)
            side = CGSize(width: max(leadingWidth, trailingWidth),
                          height: max(leading.height, trailing.height,
                                      leadingReservation.height, trailingReservation.height))
            inlineWidth = title.width + 2 * side.width + 2 * spacing
            actionWidth = leadingWidth + spacing + trailingWidth
        }

        func height(at width: CGFloat, spacing: CGFloat) -> CGFloat {
            if width >= inlineWidth { return max(title.height, side.height) }
            return title.height + spacing + side.height + (width < actionWidth ? side.height + spacing : 0)
        }
    }
}
