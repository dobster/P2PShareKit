// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "P2PShare",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "P2PShare",
            targets: ["P2PShare"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "P2PShare",
            dependencies: []),
        .testTarget(
            name: "P2PShareTests",
            dependencies: ["P2PShare"]),
    ]
)
