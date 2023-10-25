// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "CascableCoreCompatibilityAPI",
    platforms: [.macOS(.v10_13), .iOS(.v12)],
    products: [
        .library(name: "CascableCoreCompatibilityAPI", targets: ["CascableCoreCompatibilityAPI"]),
    ],
    targets: [
        .target(name: "CascableCoreCompatibilityAPI"),
        .testTarget(name: "CascableCoreCompatibilityAPITests", dependencies: ["CascableCoreCompatibilityAPI"])
    ]
)
