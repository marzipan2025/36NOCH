// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "36NOCH",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "NOCH", path: "Sources/NOCH")
    ]
)
