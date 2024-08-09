// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Demo",
    products: [
        .library(
            name: "Demo",
            targets: ["Demo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Automattic/ScreenObject", from: "0.2.3")
    ],
    targets: [
        .target(
            name: "Demo"),
        .testTarget(
            name: "DemoTests",
            dependencies: ["Demo"]),
    ]
)
