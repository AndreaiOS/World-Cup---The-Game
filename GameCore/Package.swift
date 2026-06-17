// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GameCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
    ],
    targets: [
        .target(
            name: "GameCore",
            resources: [.process("Data/Resources")]
        ),
        .testTarget(
            name: "GameCoreTests",
            dependencies: ["GameCore"],
            resources: [.process("Fixtures")]
        ),
    ]
)
