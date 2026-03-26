// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SpaceGuard",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "SpaceGuard", targets: ["SpaceGuard"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SpaceGuard",
            dependencies: [],
            path: "Sources",
            resources: [
                .copy("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        ),
        .testTarget(
            name: "SpaceGuardTests",
            dependencies: ["SpaceGuard"],
            path: "Tests"
        )
    ]
)
