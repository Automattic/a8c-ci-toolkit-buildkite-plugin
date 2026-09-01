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
        // Nothing depends on this: resolution fetches every binary target in the manifest, and leaving
        // it unreferenced keeps `swift test` running on the macOS host despite the iOS-only slices.
        .binaryTarget(
            name: "EventHorizonSDK",
            url: "https://a8c-libs.s3.amazonaws.com/ios/EventHorizon/woocommerce-2026-05-22-09-23-44/EventHorizon-woocommerce-2026-05-22-09-23-44.xcframework.zip",
            checksum: "f200c7ad8d807b48e333cefbde40500d83c798a6b592af6fa3f166c528bad083"),
        .target(
            name: "Demo"),
        .testTarget(
            name: "DemoTests",
            dependencies: ["Demo"]),
    ]
)
