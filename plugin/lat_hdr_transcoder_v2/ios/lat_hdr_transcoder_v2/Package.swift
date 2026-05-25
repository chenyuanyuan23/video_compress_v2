// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "lat_hdr_transcoder_v2",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "lat-hdr-transcoder-v2", targets: ["lat_hdr_transcoder_v2"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "lat_hdr_transcoder_v2",
            dependencies: [],
            resources: []
        )
    ]
)
