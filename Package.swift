// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Copper",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Copper", targets: ["Copper"]),
    ],
    targets: [
        .executableTarget(
            name: "Copper",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CopperTests",
            dependencies: ["Copper"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
