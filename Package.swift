// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "moyu",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(name: "MoyuCore", targets: ["MoyuCore"]),
        .executable(name: "MoyuVerify", targets: ["MoyuVerify"])
    ],
    targets: [
        .target(
            name: "MoyuCore",
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "MoyuVerify", dependencies: ["MoyuCore"])
    ]
)
