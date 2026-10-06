import SwiftUI

enum SettingsTab: Int, CaseIterable {
    case modules, media, huds, general
    var title: String {
        switch self {
        case .modules: return "Modules"
        case .media: return "Media"
        case .huds: return "HUDs"
        case .general: return "General"
        }
    }
    var icon: String {
        switch self {
        case .modules: return "square.grid.2x2.fill"
        case .media: return "music.note"
        case .huds: return "slider.horizontal.3"
        case .general: return "gearshape.fill"
        }
    }
}

struct PremiumToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                isOn.toggle()
            }
        } label: {
            ZStack {
                Capsule()
                    .fill(isOn ? Color.accentBlueGradient : Color.toggleOffGradient)
                    .frame(width: 46, height: 27)
                    .overlay {
                        Capsule()
                            .strokeBorder(isOn ? .white.opacity(0.18) : .white.opacity(0.1), lineWidth: 1)
                    }
                Circle()
                    .fill(.white)
                    .frame(width: 21, height: 21)
                    .offset(x: isOn ? 9.5 : -9.5)
                    .scaleEffect(isOn ? 1 : 0.94)
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isOn)
        }
        .buttonStyle(.plain)
        .frame(width: 46, height: 27)
    }
}

extension Color {
    static var accentBlueGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.05, green: 0.5, blue: 1.0), Color(red: 0.25, green: 0.62, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
    }
    static var toggleOffGradient: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.12)], startPoint: .top, endPoint: .bottom)
    }
}

struct PillTabBar: View {
    @Binding var selection: SettingsTab
    @Namespace private var pill
    var body: some View {
        HStack(spacing: 2) {
            ForEach(SettingsTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        selection = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 13, weight: selection == tab ? .semibold : .medium))
                    }
                    .foregroundStyle(selection == tab ? .white : .white.opacity(0.5))
                    .padding(.vertical, 7)
                    .padding(.horizontal, 14)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(Color.white.opacity(0.13))
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.06))
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

struct ModuleRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.gradient)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(isOn ? .white : .white.opacity(0.85))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            PremiumToggle(isOn: $isOn)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                isOn.toggle()
            }
        }
    }
}

struct SettingRow: View {
    let icon: String
    let color: Color
    let title: String
    var subtitle: String? = nil
    var help: String? = nil
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.gradient)
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 7) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                    if let help {
                        SettingsInfoIcon(help: help)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
            Spacer()
            PremiumToggle(isOn: $isOn)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
    }
}

struct VolumeHUDStyleSelector: View {
    @Binding var selection: String

    private var selectedStyle: VolumeHUDStyle {
        VolumeHUDStyle(rawValue: selection) ?? .inline
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(VolumeHUDStyle.allCases) { style in
                let isSelected = selectedStyle == style
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selection = style.rawValue
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: style.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(style.title)
                            .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                    }
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background {
                        if isSelected {
                            Capsule().fill(.white.opacity(0.15))
                        }
                    }
                }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityLabel("\(style.title) volume and brightness indicators")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(.white.opacity(0.07)))
        .overlay { Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1) }
        .frame(width: 190)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .textCase(.uppercase)
                        .tracking(0.4)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.38))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
            VStack(spacing: 0) {
                content
            }
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    }
            }
        }
    }
}

struct CardDivider: View {
    var body: some View {
        Divider()
            .background(Color.white.opacity(0.07))
            .padding(.leading, 56)
            .padding(.trailing, 14)
    }
}

struct QuickActionButton: View {
    let title: String
    let prominent: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(prominent ? .white : .white.opacity(0.7))
                .padding(.vertical, 6)
                .padding(.horizontal, 13)
                .background {
                    Capsule()
                        .fill(prominent ? Color(red: 0.05, green: 0.5, blue: 1.0) : Color.white.opacity(0.09))
                        .overlay {
                            if !prominent {
                                Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            }
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

struct SettingsInfoIcon: View {
    let help: String

    var body: some View {
        Image(systemName: "info.circle.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .help(help)
            .accessibilityLabel(help)
    }
}

