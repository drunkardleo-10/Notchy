import SwiftUI

struct MirrorView: View {
    @StateObject private var camera = CameraController()

    var body: some View {
        Group {
            switch camera.status {
            case .denied:
                message("camera.fill", "Camera access is turned off", "Enable it in System Settings → Privacy → Camera")
            case .unavailable:
                message("video.slash", "No camera found", nil)
            default:
                CameraPreview(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.15)))
                    .frame(maxWidth: 220)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    private func message(_ icon: String, _ title: String, _ detail: String?) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 22))
            Text(title).font(.system(size: 12))
            if let detail { Text(detail).font(.system(size: 10)) }
        }
        .foregroundStyle(.white.opacity(0.5))
    }
}
