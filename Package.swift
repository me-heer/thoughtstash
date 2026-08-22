// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ThoughtStash",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "ThoughtStash", targets: ["ThoughtStash"]),
    ],
    targets: [
        .executableTarget(
            name: "ThoughtStash",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ThoughtStashTests",
            dependencies: ["ThoughtStash"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
