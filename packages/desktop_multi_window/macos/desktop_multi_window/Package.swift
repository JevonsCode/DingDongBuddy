// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "desktop_multi_window",
    platforms: [
        .macOS("10.15")
    ],
    products: [
        .library(
            name: "desktop-multi-window",
            targets: ["desktop_multi_window"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "desktop_multi_window",
            dependencies: [
                .product(
                    name: "FlutterFramework",
                    package: "FlutterFramework"
                )
            ]
        )
    ]
)
