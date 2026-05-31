// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KokoroBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "KokoroBar", targets: ["KokoroBar"])
    ],
    targets: [
        .executableTarget(name: "KokoroBar")
    ]
)
