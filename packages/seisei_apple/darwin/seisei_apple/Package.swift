// swift-tools-version: 5.9

import PackageDescription

// One source tree for iOS and macOS (`sharedDarwinSource` in pubspec.yaml).
//
// `SeiseiAppleCore` holds the bridge logic that needs neither Flutter nor
// FoundationModels, so `swift test` can check it on any platform. The plugin
// target compiles to nothing outside a Flutter build.
let package = Package(
    name: "seisei_apple",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "seisei-apple", targets: ["seisei_apple"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "seisei_apple",
            dependencies: ["SeiseiAppleCore"]
        ),
        .target(name: "SeiseiAppleCore"),
        .testTarget(
            name: "SeiseiAppleCoreTests",
            dependencies: ["SeiseiAppleCore"]
        ),
    ]
)
