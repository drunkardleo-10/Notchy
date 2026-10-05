import AVFoundation
import SwiftUI

final class CameraController: ObservableObject {
    enum Status { case idle, running, denied, unavailable }

    @Published var status: Status = .idle
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "camera")
    private var configured = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { granted ? self.run() : { self.status = .denied }() }
            }
        default: status = .denied
        }
    }

    private func run() {
        queue.async {
            if !self.configured {
                guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    DispatchQueue.main.async { self.status = .unavailable }
                    return
                }
                self.session.addInput(input)
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.status = .running }
        }
    }
    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
        status = .idle
    }
}
