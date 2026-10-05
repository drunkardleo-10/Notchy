import Foundation
import IOKit
import Darwin

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var cpu: Double = 0
    @Published private(set) var gpu: Double?
    @Published private(set) var memory: Double = 0
    @Published private(set) var memoryUsedGB: Double = 0
    @Published private(set) var memoryTotalGB: Double = 0
    @Published private(set) var disk: Double = 0
    @Published private(set) var diskFreeGB: Double = 0
    @Published private(set) var netDown: Double = 0
    @Published private(set) var netUp: Double = 0

    private var timer: Timer?
    private var lastTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    private var lastNet: (down: UInt64, up: UInt64, time: Date)?

    func start() {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastTicks = nil
        lastNet = nil
    }

    private func sample() {
        sampleCPU()
        gpu = Self.gpuUtilization()
        sampleMemory()
        sampleDisk()
        sampleNetwork()
    }

    private func sampleCPU() {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return }
        let now = (user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
        if let last = lastTicks {
            let user = Double(now.user &- last.user), sys = Double(now.system &- last.system)
            let idle = Double(now.idle &- last.idle), nice = Double(now.nice &- last.nice)
            let total = user + sys + idle + nice
            if total > 0 { cpu = (user + sys + nice) / total }
        }
        lastTicks = now
    }

    private func sampleMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return }
        let page = Double(vm_kernel_page_size)
        let used = (Double(stats.active_count) + Double(stats.wire_count) + Double(stats.compressor_page_count)) * page
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        memoryUsedGB = used / 1e9
        memoryTotalGB = total / 1e9
        memory = min(used / total, 1)
    }

    private func sampleDisk() {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let free = values.volumeAvailableCapacityForImportantUsage, let total = values.volumeTotalCapacity, total > 0 else { return }
        diskFreeGB = Double(free) / 1e9
        disk = 1 - Double(free) / Double(total)
    }

    private func sampleNetwork() {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return }
        defer { freeifaddrs(addrs) }
        var down: UInt64 = 0, up: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = cursor {
            let name = String(cString: ifa.pointee.ifa_name)
            if name.hasPrefix("en"), let sa = ifa.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_LINK), let data = ifa.pointee.ifa_data {
                let counters = data.assumingMemoryBound(to: if_data.self).pointee
                down += UInt64(counters.ifi_ibytes)
                up += UInt64(counters.ifi_obytes)
            }
            cursor = ifa.pointee.ifa_next
        }
        let now = Date()
        if let last = lastNet, down >= last.down, up >= last.up {
            let dt = now.timeIntervalSince(last.time)
            if dt > 0 { netDown = Double(down - last.down) / dt; netUp = Double(up - last.up) / dt }
        }
        lastNet = (down, up, now)
    }

    private static func gpuUtilization() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var best: Double?
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            if let stats = IORegistryEntryCreateCFProperty(entry, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any],
               let util = stats["Device Utilization %"] as? Int {
                best = max(best ?? 0, Double(util) / 100)
            }
        }
        return best
    }
}
