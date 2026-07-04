// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "451Core",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Core451", targets: ["Core451"]),
        .executable(name: "451cli", targets: ["cli451"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.3.0"
        ),
    ],
    targets: [
        .target(
            name: "Core451",
            dependencies: [],
            path: "Sources/Core451",
            resources: [
                .process("Resources/Onboarding")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "cli451",
            dependencies: [
                "Core451",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/cli451"
        ),
        .testTarget(
            name: "Core451Tests",
            dependencies: ["Core451"],
            path: "Tests/Core451Tests"
        ),
    ]
)
