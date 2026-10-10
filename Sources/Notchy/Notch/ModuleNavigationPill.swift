import SwiftUI

enum ModuleNavigationMetrics {
    static let width: CGFloat = 28
    static let height: CGFloat = 64
    static let gap: CGFloat = 10
    static let openingTravel: CGFloat = 44
    static let trailingHitExtension: CGFloat = 8
    static let panelWidthAllowance = trailingHitExtension * 2 + 12
}

struct ModuleNavigationPill: View {
    let tabs: [NotchTab]
    let selection: NotchTab
    let onSelect: (NotchTab) -> Void
    @Namespace private var namespace

    private var firstTab: NotchTab? {
        tabs.first
    }

    private var isOnFirstTab: Bool {
        selection == firstTab
    }

    private var nextNonFirstTab: NotchTab? {
        guard tabs.count > 1 else { return nil }
        let selectedIndex = tabs.firstIndex(of: selection) ?? 0
        let nextIndex = selectedIndex == 0 || selectedIndex == tabs.count - 1
            ? 1
            : selectedIndex + 1
        return tabs[nextIndex]
    }

    private let inset: CGFloat = 3

    private var slotHeight: CGFloat {
        (ModuleNavigationMetrics.height - inset * 2) / 2
    }

    private var secondIcon: String {
        isOnFirstTab ? (nextNonFirstTab?.icon ?? "ellipsis") : selection.icon
    }

    private func slot(icon: String, isActive: Bool) -> some View {
        ZStack {
            if isActive {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: ModuleNavigationMetrics.width - inset * 2, height: slotHeight)
                    .matchedGeometryEffect(id: "activeSlot", in: namespace)
            }
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.45))
                .id(icon)
                .transition(.modifier(
                    active: IconBlurMorph(blur: 5, opacity: 0, scale: 0.55),
                    identity: IconBlurMorph(blur: 0, opacity: 1, scale: 1)
                ))
        }
        .animation(.easeInOut(duration: 0.24), value: icon)
        .frame(width: ModuleNavigationMetrics.width, height: slotHeight)
        .contentShape(Rectangle())
    }

    var body: some View {
        VStack(spacing: 0) {
            if let firstTab {
                Button {
                    onSelect(firstTab)
                } label: {
                    slot(icon: firstTab.icon, isActive: isOnFirstTab)
                }
                .buttonStyle(ModuleNavigationButtonStyle())
                .help(firstTab.title)
                .accessibilityLabel("First module: \(firstTab.title)")
                .accessibilityAddTraits(isOnFirstTab ? .isSelected : [])
            }

            if let nextNonFirstTab {
                Button {
                    onSelect(nextNonFirstTab)
                } label: {
                    slot(icon: secondIcon, isActive: !isOnFirstTab)
                }
                .buttonStyle(ModuleNavigationButtonStyle())
                .help(isOnFirstTab ? "Next module: \(nextNonFirstTab.title)" : "\(selection.title) · next: \(nextNonFirstTab.title)")
                .accessibilityLabel("Next module: \(nextNonFirstTab.title)")
                .accessibilityAddTraits(!isOnFirstTab ? .isSelected : [])
            }
        }
        .padding(.vertical, inset)
        .frame(width: ModuleNavigationMetrics.width, height: ModuleNavigationMetrics.height)
        .background {
            let capsule = Capsule()
            Group {
                if #available(macOS 26.0, *) {
                    Color.clear.glassEffect(.regular, in: capsule)
                } else {
                    capsule
                        .fill(Color.white.opacity(0.055))
                        .overlay(capsule.stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                }
            }
        }
        .animation(NotchAnimation.tabSelect, value: selection)
        .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
    }
}

private struct IconBlurMorph: ViewModifier {
    let blur: CGFloat
    let opacity: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content.blur(radius: blur).opacity(opacity).scaleEffect(scale)
    }
}

private struct ModuleNavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
