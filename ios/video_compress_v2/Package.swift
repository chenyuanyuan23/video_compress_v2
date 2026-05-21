// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "video_compress_v2",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "video-compress-v2", targets: ["video_compress_v2"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "video_compress_v2",
            dependencies: [],
            resources: []
        )
    ]
)
