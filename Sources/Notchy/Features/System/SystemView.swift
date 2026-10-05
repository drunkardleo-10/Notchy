import SwiftUI

struct SystemView: View {
    @ObservedObject var system: SystemMonitor

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                Gauge(title: "CPU", value: system.cpu, detail: "\(Int(system.cpu * 100))%", tint: .blue)
                Gauge(title: "GPU", value: system.gpu ?? 0, detail: system.gpu.map { "\(Int($0 * 100))%" } ?? "n/a", tint: .purple)
                Gauge(title: "Memory", value: system.memory,
                      detail: String(format: "%.1f/%.0f GB", system.memoryUsedGB, system.memoryTotalGB), tint: .orange)
                Gauge(title: "Disk", value: system.disk, detail: String(format: "%.0f GB free", system.diskFreeGB), tint: .green)
            }
            HStack(spacing: 22) {
                Label(Self.rate(system.netDown), systemImage: "arrow.down")
                Label(Self.rate(system.netUp), systemImage: "arrow.up")
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit()).foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { system.start() }
        .onDisappear { system.stop() }
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        switch bytesPerSecond {
        case ..<1_000: return String(format: "%.0f B/s", bytesPerSecond)
        case ..<1_000_000: return String(format: "%.0f KB/s", bytesPerSecond / 1_000)
        default: return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
        }
    }
}

private struct Gauge: View {
    let title: String
    let value: Double
    let detail: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 6)
                Circle().trim(from: 0, to: min(max(value, 0), 1))
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                Text(title).font(.system(size: 10, weight: .semibold))
            }
            .frame(width: 54, height: 54)
            Text(detail).font(.system(size: 9).monospacedDigit()).foregroundStyle(.white.opacity(0.6))
        }
        .animation(.easeOut(duration: 0.4), value: value)
    }
}
