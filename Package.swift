// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "XcodeManager",
    products: [
        .library(name: "XcodeManager", targets: ["XcodeManager"])
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "4.0.0")
    ],
    targets: [
        .target(name: "XcodeManager", dependencies: ["SwiftyJSON"])
    ]
)
