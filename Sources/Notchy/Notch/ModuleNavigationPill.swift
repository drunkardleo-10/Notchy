import SwiftUI

enum ModuleNavigationMetrics {
    static let width: CGFloat = 24
    static let minimumHeight: CGFloat = 48
    static let maximumHeight: CGFloat = 58
    static let heightBase: CGFloat = 80
    static let heightPerTab: CGFloat = 9
    static let gap: CGFloat = 2
    static let openingTravel: CGFloat = 44
    static let trailingHitExtension = gap + width
    static let panelWidthAllowance = trailingHitExtension * 2 + 12
}

struct ModuleNavigationPill: View {
    let tabs: [NotchTab]
    let selection: NotchTab
    let onSelect: (NotchTab) -> Void

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

    private var pillHeight: CGFloat {
        min(
            ModuleNavigationMetrics.maximumHeight,
            max(
                ModuleNavigationMetrics.minimumHeight,
                ModuleNavigationMetrics.heightBase + CGFloat(tabs.count) * ModuleNavigationMetrics.heightPerTab
            )
        )
    }

    private var slotHeight: CGFloat {
        max(0, (pillHeight - 24) / 2)
    }

    private func marker(isActive: Bool) -> some View {
        Capsule()
            .fill(isActive ? Color.white : Color.white.opacity(0.42))
            .frame(
                width: isActive ? 6 : 7,
                height: isActive ? min(26, slotHeight * 0.7) : 7
            )
            .frame(width: 28, height: slotHeight)
            .contentShape(Rectangle())
    }

    var body: some View {
        VStack(spacing: 0) {
            if let firstTab {
                Button {
                    onSelect(firstTab)
                } label: {
                    marker(isActive: isOnFirstTab)
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
                    marker(isActive: !isOnFirstTab)
                }
                .buttonStyle(ModuleNavigationButtonStyle())
                .help("Next module: \(nextNonFirstTab.title)")
                .accessibilityLabel("Next module: \(nextNonFirstTab.title)")
                .accessibilityAddTraits(!isOnFirstTab ? .isSelected : [])
            }
        }
        .padding(.vertical, 12)
        .frame(width: ModuleNavigationMetrics.width, height: pillHeight)
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

private struct ModuleNavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
