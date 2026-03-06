// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Aptune",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "aptune", targets: ["Aptune"])
    ],
    targets: [
        .executableTarget(
            name: "Aptune",
            dependencies: ["CLI", "AudioCapture", "VAD", "VolumeControl", "Coordinator"]
        ),
        .target(name: "CLI"),
        .target(name: "AudioCapture"),
        .target(
            name: "VAD",
            resources: [
                .copy("Resources/FireRedVAD.mlpackage")
            ]
        ),
        .target(name: "VolumeControl"),
        .target(name: "Coordinator", dependencies: ["CLI", "VAD", "VolumeControl"]),
        .testTarget(name: "CLITests", dependencies: ["CLI"]),
        .testTarget(name: "VADTests", dependencies: ["VAD"]),
        .testTarget(name: "VolumeControlTests", dependencies: ["VolumeControl"]),
        .testTarget(name: "CoordinatorTests", dependencies: ["Coordinator", "CLI", "VAD", "VolumeControl"])
    ]
)
