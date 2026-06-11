// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "seisei_apple",
    platforms: [
        .iOS("13.0")
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
