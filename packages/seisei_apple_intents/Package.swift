// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SeiseiAppleIntents",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SeiseiAppleIntents",
            targets: ["SeiseiAppleIntents"]
        ),
    ],
    targets: [
        .target(
            name: "SeiseiAppleIntents"
        ),
        .testTarget(
            name: "SeiseiAppleIntentsTests",
            dependencies: ["SeiseiAppleIntents"]
        ),
    ]
)
