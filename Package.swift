// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "shortcut-detection-kit",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "ShortcutDetectionKit",
            targets: ["ShortcutDetectionKit"])
    ],
    targets: [
        .target(
            name: "ShortcutDetectionKit"
        )
    ]
)
