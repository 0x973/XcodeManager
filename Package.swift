// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "XcodeManager",
    products: [
        .library(name: "XcodeManager", targets: ["XcodeManager"])
    ],
    dependencies: [],
    targets: [
        .target(name: "XcodeManager"),
        .testTarget(name: "XcodeManagerTests", dependencies: ["XcodeManager"])
    ]
)
