import SwiftUI

struct PermissionSample: View {
    let kind: PermissionKind

    var body: some View {
        switch kind {
        case .accessibility:
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: 13, weight: .semibold))
                Capsule().fill(Color.white.opacity(0.2)).frame(width: 150, height: 6)
                    .overlay(alignment: .leading) { Capsule().fill(Color.white).frame(width: 96, height: 6) }
            }
        case .automation:
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.25)).frame(width: 34, height: 34)
                    .overlay(Image(systemName: "music.note").font(.system(size: 13, weight: .semibold)))
                VStack(alignment: .leading, spacing: 5) {
                    Capsule().fill(Color.white.opacity(0.7)).frame(width: 110, height: 7)
                    Capsule().fill(Color.white.opacity(0.35)).frame(width: 70, height: 6)
                }
            }
        case .calendar:
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(Color.blue).frame(width: 4, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Design review").font(.system(size: 12.5, weight: .semibold))
                    Text("in 15 minutes").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                }
                Text("Join").font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10).frame(height: 22)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
            }
        case .location:
            HStack(spacing: 8) {
                Image(systemName: "cloud.sun.fill").symbolRenderingMode(.multicolor).font(.system(size: 18))
                Text("21°").font(.system(size: 20, weight: .semibold))
                Image(systemName: "sunrise.fill").font(.system(size: 13)).foregroundStyle(.orange)
                Text("6:12").font(.system(size: 12, weight: .medium))
            }
        case .camera:
            RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.15)).frame(width: 72, height: 44)
                .overlay(Image(systemName: "person.crop.square").font(.system(size: 18)))
        }
    }
}
