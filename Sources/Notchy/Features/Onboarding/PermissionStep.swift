import SwiftUI

struct PermissionStep: View {
    let kind: PermissionKind
    @ObservedObject var model: OnboardingModel

    private var granted: Bool { model.permissionStatus == .granted }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NotchyGuide(pose: granted ? .cheer : .idle,
                        title: granted ? kind.thanks : kind.title,
                        message: granted ? "That's all I need here. Take a look, then continue." : kind.reason,
                        cell: 2,
                        reservedLines: 2)

            HStack(alignment: .top, spacing: 10) {
                PermissionChecklist(plan: model.permissionPlan, current: kind, granted: granted, resolved: model.resolved)
                    .frame(width: 176)
                PermissionStage(kind: kind, model: model)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: granted)
    }
}

private struct PermissionChecklist: View {
    let plan: [PermissionKind]
    let current: PermissionKind
    let granted: Bool
    let resolved: [PermissionKind: Bool]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(plan, id: \.self) { kind in
                row(kind)
            }
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.white.opacity(0.04)))
    }

    private func row(_ kind: PermissionKind) -> some View {
        let isCurrent = kind == current
        let done = isCurrent ? granted : resolved[kind] == true
        let skipped = !isCurrent && resolved[kind] == false
        return HStack(spacing: 8) {
            Image(systemName: kind.symbol)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(isCurrent ? .white : .white.opacity(0.55))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white.opacity(isCurrent ? 0.16 : 0.07)))
            Text(kind.shortTitle)
                .font(.system(size: 11.5, weight: isCurrent ? .semibold : .medium))
                .foregroundStyle(.white.opacity(isCurrent ? 0.95 : 0.55))
            Spacer(minLength: 4)
            Group {
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(OnboardingTheme.success)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                } else if skipped {
                    Text("Later")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                } else if isCurrent {
                    PulseDot()
                } else {
                    Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1).frame(width: 8, height: 8)
                }
            }
            .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(isCurrent ? 0.08 : 0))
        )
    }
}

private struct PermissionStage: View {
    let kind: PermissionKind
    @ObservedObject var model: OnboardingModel

    private var status: PermissionStatus { model.permissionStatus }
    private var granted: Bool { status == .granted }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if granted {
                    PermissionPayoff(kind: kind, model: model, media: model.media, calendar: model.calendar)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    PermissionSample(kind: kind)
                        .blur(radius: 1.2)
                        .opacity(0.4)
                        .overlay {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.15)))
                        }
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.35)))
            .overlay(alignment: .topLeading) {
                Text(granted ? "LIVE" : "UNLOCKS")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(granted ? OnboardingTheme.success : .white.opacity(0.4))
                    .padding(6)
            }

            HStack(spacing: 10) {
                actions
                Spacer(minLength: 6)
                Label("Stays on this Mac", systemImage: "lock.shield")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .labelStyle(.titleAndIcon)
            }
            .frame(height: 30)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.white.opacity(0.07)))
    }

    @ViewBuilder
    private var actions: some View {
        switch status {
        case .granted:
            Label("Allowed", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OnboardingTheme.success)
        case .denied:
            OnboardingButton(title: "Open System Settings", symbol: "arrow.up.forward") { model.openSettings(kind) }
        case .unavailable:
            OnboardingButton(title: "Open Music") { model.request(kind) }
        case .undetermined:
            OnboardingButton(title: kind.actionTitle, symbol: kind == .accessibility ? "arrow.up.forward" : nil) { model.request(kind) }
        }
    }
}
