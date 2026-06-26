// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SpaceLens",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SpaceLens", targets: ["SpaceLens"])
    ],
    targets: [
        .executableTarget(
            name: "SpaceLens"
        ),
        .testTarget(
            name: "SpaceLensTests",
            dependencies: ["SpaceLens"]
        )
    ]
)
