// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "StringsFile",
    products: [
        .library(
            name: "StringsFile",
            targets: ["StringsFile"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "StringsFile",
            dependencies: []),
        .testTarget(
            name: "StringsFileTests",
            dependencies: ["StringsFile"]),
    ]
)
