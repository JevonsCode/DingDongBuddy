// swift-tools-version: 5.9
import PackageDescription

// Compile the exact host sources without launching DingDong or requesting TCC.
let package = Package(
    name: "DingDongSelectionHost",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "DingDongSelectionHost",
            path: ".",
            exclude: ["Tests"],
            sources: ["SelectionPluginController.swift", "SelectionPluginRuntime.swift"]
        ),
        .testTarget(
            name: "DingDongSelectionHostTests",
            dependencies: ["DingDongSelectionHost"],
            path: "Tests"
        )
    ]
)
