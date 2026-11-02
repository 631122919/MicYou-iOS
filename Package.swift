// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

// The linker records the deployment target as the SDK version unless told otherwise, on Linux
// and on macOS alike under xtool, and iOS then runs the app in compatibility mode without
// Liquid Glass. This fork pins the deployment target to iOS 16, the rest of the file keeps the
// upstream layout otherwise
let sdkVersion = Context.environment["MICYOU_IOS_SDK_VERSION"] ?? "27.1"
let linkSDKVersion: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "-platform_version", "-Xlinker", "ios", "-Xlinker", "16.0", "-Xlinker", sdkVersion]),
]

// Release builds leave out local symbols and debug info, which take more than half of the
// binary. Crash reports then show addresses for app frames, debug builds keep their symbols
let stripSymbols: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "-x", "-Xlinker", "-S"], .when(configuration: .release)),
]

let package = Package(
    name: "MicYou",
    platforms: [
        .iOS(.v16),
        .macOS(.v15),
    ],
    products: [
        // xtool expects exactly one library product for the app
        .library(name: "MicYou", targets: ["MicYou"]),
    ],
    dependencies: [
        .package(path: "Packages/MicYouProtocol"),
        .package(path: "Packages/MicYouCore"),
    ],
    targets: [
        .target(name: "MicYouShared"),
        .target(
            name: "MicYou",
            dependencies: [
                "MicYouShared",
                .product(name: "MicYouProtocol", package: "MicYouProtocol"),
                .product(name: "MicYouCore", package: "MicYouCore"),
            ],
            linkerSettings: linkSDKVersion + stripSymbols
        ),
    ]
)
