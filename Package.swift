// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Upright",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "UprightCore"),
        .executableTarget(name: "Upright", dependencies: ["UprightCore"]),
        .testTarget(name: "UprightCoreTests", dependencies: ["UprightCore"]),
    ]
)
