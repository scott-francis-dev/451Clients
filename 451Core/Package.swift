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
        // `Sources/Core451` is a symlink to the repo-level `Common/` directory,
        // which is the shared code the Xcode app targets compile directly.
        // Keeping one copy avoids the package and the apps drifting apart.
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
        // Matches Core451's language mode so the tests see the same
        // concurrency rules as the code they exercise.
        .testTarget(
            name: "Core451Tests",
            dependencies: ["Core451"],
            path: "Tests/Core451Tests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // Black-box tests: these run the built `451cli` binary as a subprocess,
        // so they cover argument parsing, exit codes and output as shipped.
        .testTarget(
            name: "cli451Tests",
            dependencies: ["cli451"],
            path: "Tests/cli451Tests"
        ),
    ]
)
