// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "seisei_apple",
    platforms: [
        .macOS("10.15")
    ],
    products: [
        .library(name: "seisei-apple", targets: ["seisei_apple"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "seisei_apple",
            dependencies: []
        )
    ]
)
