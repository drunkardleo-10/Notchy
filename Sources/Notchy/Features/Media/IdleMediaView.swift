import SwiftUI

struct EmptyMediaView: View {
    var onPlay: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color.white.opacity(0.09))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Not Playing")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text("—")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer(minLength: 8)

                EqualizerBars(active: false, useGradient: true, tint: .white)
            }

            HStack(spacing: 10) {
                Text("0:00")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(minWidth: 28, alignment: .leading)
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 5)
                Text("--:--")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(minWidth: 34, alignment: .trailing)
            }
            .frame(height: 12)

            ZStack {
                HStack(spacing: 20) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 19, weight: .bold))
                        .frame(width: 36, height: 36)
                        .opacity(0.4)
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 26, weight: .bold))
                    }
                    .buttonStyle(MediaControlButtonStyle())
                    Image(systemName: "forward.fill")
                        .font(.system(size: 19, weight: .bold))
                        .frame(width: 36, height: 36)
                        .opacity(0.4)
                }
                HStack {
                    Spacer()
                    Button {
                        NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(MediaControlButtonStyle())
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
