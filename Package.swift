// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Copper",
    platforms: [.macOS(.v26)],
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
