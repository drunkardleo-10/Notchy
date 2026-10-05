import Foundation

@MainActor
final class ShortcutsModel: ObservableObject {
    @Published private(set) var names: [String] = []
    @Published private(set) var loaded = false
    @Published var status: String?

    func load() {
        guard !loaded else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let out = Self.run(["list"])
            let list = out.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            DispatchQueue.main.async { self.names = list; self.loaded = true }
        }
    }

    func reload() { loaded = false; load() }

    func run(_ name: String) {
        status = "Running \(name)…"
        DispatchQueue.global(qos: .userInitiated).async {
            _ = Self.run(["run", name])
            DispatchQueue.main.async {
                self.status = "Ran \(name)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if self.status == "Ran \(name)" { self.status = nil } }
            }
        }
    }

    nonisolated private static func run(_ args: [String]) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        guard (try? proc.run()) != nil else { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
