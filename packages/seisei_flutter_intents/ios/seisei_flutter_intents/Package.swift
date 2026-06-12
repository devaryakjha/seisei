// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "seisei_flutter_intents",
    platforms: [
        .iOS("13.0")
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
