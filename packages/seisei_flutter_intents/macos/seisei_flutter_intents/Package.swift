// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "seisei_flutter_intents",
    platforms: [
        .macOS("10.15")
    ],
    products: [
        .library(name: "seisei-flutter-intents", targets: ["seisei_flutter_intents"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "seisei_flutter_intents",
            dependencies: []
        )
    ]
)
