// swift-tools-version:5.3

//------------------------------------------------------------------------------
// Copyright (c) 2021 Cunningo S.L.U. and the project authors
//
// Licensed under the Apache License, Version 2.0
// See LICENSE.txt for license information:
// https://github.com/cunningo/StringsFile/blob/main/LICENSE.txt
//------------------------------------------------------------------------------

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
