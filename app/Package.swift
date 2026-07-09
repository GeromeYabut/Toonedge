// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ToonEdge",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ToonEdgeAppCore",
            targets: ["ToonEdgeAppCore"]
        )
    ],
    targets: [
        .target(
            name: "ToonEdgeAppCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ToonEdgeAppCoreTests",
            dependencies: ["ToonEdgeAppCore"],
            resources: [.process("Fixtures")]
        )
    ]
)
