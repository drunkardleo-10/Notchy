import SwiftUI

enum NotchAccessoryLayout {
    static func size(notch: CGSize, leadingWidth: CGFloat, trailingWidth: CGFloat) -> CGSize {
        CGSize(width: notch.width + leadingWidth + trailingWidth, height: notch.height)
    }
}

/// Lays out content on either side of the notch and reports the matching total size.
struct NotchAccessory<Leading: View, Trailing: View>: View {
    let notch: CGSize
    let leadingWidth: CGFloat
    let trailingWidth: CGFloat
    let leadingAlignment: Alignment
    let trailingAlignment: Alignment
    let leadingInset: CGFloat
    let trailingInset: CGFloat
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    init(
        notch: CGSize,
        leadingWidth: CGFloat,
        trailingWidth: CGFloat,
        leadingAlignment: Alignment = .center,
        trailingAlignment: Alignment = .center,
        leadingInset: CGFloat = 0,
        trailingInset: CGFloat = 0,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.notch = notch
        self.leadingWidth = leadingWidth
        self.trailingWidth = trailingWidth
        self.leadingAlignment = leadingAlignment
        self.trailingAlignment = trailingAlignment
        self.leadingInset = leadingInset
        self.trailingInset = trailingInset
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 0) {
            leading
                .padding(.trailing, leadingInset)
                .frame(width: leadingWidth, alignment: leadingAlignment)
            Spacer().frame(width: notch.width)
            trailing
                .padding(.leading, trailingInset)
                .frame(width: trailingWidth, alignment: trailingAlignment)
        }
        .frame(width: size.width, height: size.height)
    }

    var size: CGSize {
        NotchAccessoryLayout.size(notch: notch, leadingWidth: leadingWidth, trailingWidth: trailingWidth)
    }
}
