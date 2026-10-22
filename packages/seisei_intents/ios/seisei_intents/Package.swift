// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "seisei_intents",
    platforms: [
        .iOS("13.0")
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
