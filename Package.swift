// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TokenBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TokenBar", targets: ["TokenBar"]),
        .executable(name: "tokenbar", targets: ["TokenBarCLI"]),
        .library(name: "TokenBarCore", targets: ["TokenBarCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/steipete/SweetCookieKit", from: "0.4.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // Shared library — compiles on macOS and Linux
        .target(
            name: "TokenBarCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SweetCookieKit", package: "SweetCookieKit", condition: .when(platforms: [.macOS])),
            ],
            path: "Sources/TokenBarCore"
        ),

        // macOS menu bar app
        .executableTarget(
            name: "TokenBar",
            dependencies: [
                "TokenBarCore",
                .product(name: "SweetCookieKit", package: "SweetCookieKit"),
            ],
            path: "Sources/TokenBar"
        ),

        // CLI tool — macOS + Linux compatible
        .executableTarget(
            name: "TokenBarCLI",
            dependencies: [
                "TokenBarCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/TokenBarCLI"
        ),

        // Unit tests for TokenBarCore
        .testTarget(
            name: "TokenBarCoreTests",
            dependencies: ["TokenBarCore"],
            path: "Tests/TokenBarCoreTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
