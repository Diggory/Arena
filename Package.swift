// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "SPMPlayground",
    products: [
        .executable(name: "spm-playground", targets: ["spm-playground"]),
        .library(name: "SPMPlayground", targets: ["SPMPlayground"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-package-manager", .revision("swift-5.1.3-RELEASE")),
        .package(url: "https://github.com/mxcl/Path.swift.git", from: "0.13.0"),
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.0.0"),
        .package(url: "https://github.com/hartbit/Yaap.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "spm-playground",
            dependencies: ["SPMPlayground"]),
        .target(
            name: "SPMPlayground",
            dependencies: ["Path", "ShellOut", "SwiftPM-auto", "Yaap"]),
        .testTarget(
            name: "SPMPlaygroundTests",
            dependencies: ["SPMPlayground"]),
    ]
)
