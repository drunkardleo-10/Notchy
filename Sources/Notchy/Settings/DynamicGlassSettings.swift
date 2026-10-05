import SwiftUI

struct DynamicGlassSettingsCard: View {
    @Binding var glassLevel: Double
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Dynamic Glass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.94))
            Text("Choose how much of the scene shows through. Dragging opens the shelf for a live preview.")
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                DynamicGlassPreview(glassLevel: glassLevel)
                    .frame(height: 148)

                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)

                Text("Glass level")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))

                Slider(value: $glassLevel, in: 0...1, onEditingChanged: onEditingChanged)
                    .tint(Color(red: 0.20, green: 0.48, blue: 1.0))
                    .accessibilityLabel("Glass level")
                    .accessibilityValue("\(Int(glassLevel * 100)) percent")

                HStack {
                    Text("Black")
                    Spacer()
                    Text("Glass")
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                    }
            }
        }
    }
}

private struct DynamicGlassPreview: View {
    let glassLevel: Double

    var body: some View {
        GeometryReader { proxy in
            let panelShape = NotchShape(topRadius: 18, bottomRadius: 25)
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.04, green: 0.08, blue: 0.72),
                                Color(red: 0.08, green: 0.18, blue: 0.92),
                                Color(red: 0.10, green: 0.25, blue: 0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Ellipse()
                    .fill(Color.cyan.opacity(0.5))
                    .frame(width: proxy.size.width * 0.46, height: proxy.size.height * 0.40)
                    .blur(radius: 24)
                    .offset(x: -proxy.size.width * 0.34, y: proxy.size.height * 0.37)

                Ellipse()
                    .fill(Color.white.opacity(0.68))
                    .frame(width: proxy.size.width * 0.36, height: proxy.size.height * 0.34)
                    .blur(radius: 18)
                    .offset(x: proxy.size.width * 0.39, y: -proxy.size.height * 0.32)

                Ellipse()
                    .fill(Color.purple.opacity(0.62))
                    .frame(width: proxy.size.width * 0.42, height: proxy.size.height * 0.28)
                    .blur(radius: 22)
                    .offset(x: proxy.size.width * 0.12, y: proxy.size.height * 0.47)

                ZStack(alignment: .topLeading) {
                    if #available(macOS 26.0, *) {
                        Color.clear.glassEffect(.clear, in: panelShape)
                    } else {
                        Rectangle().fill(.ultraThinMaterial)
                    }

                    Color.black.opacity(DynamicGlassStyle.blackOpacity(for: glassLevel))

                    DynamicGlassGradient(expansion: 1)

                    EmptyMediaView()
                        .padding(.horizontal, 30)
                }
                .frame(width: proxy.size.width * 0.86, height: proxy.size.height * 0.94)
                .clipShape(panelShape)
                .overlay {
                    panelShape.stroke(.white.opacity(0.20), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.36), radius: 14, y: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dynamic glass preview")
    }
}
