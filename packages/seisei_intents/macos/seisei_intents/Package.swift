// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "seisei_intents",
    platforms: [
        .macOS("10.15")
    ],
    products: [
        .library(name: "seisei-intents", targets: ["seisei_intents"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "seisei_intents",
            dependencies: []
        )
    ]
)
