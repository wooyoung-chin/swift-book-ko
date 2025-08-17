// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftBookKorean",
    products: [
        .library(name: "SwiftBookKorean", targets: ["SwiftBookKorean"])
    ],
    targets: [
        .target(
            name: "SwiftBookKorean",
            dependencies: []
        )
    ]
)
