// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "notchy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "notchy",
            path: "Sources/Notchy"
        )
    ]
)
