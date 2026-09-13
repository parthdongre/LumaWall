// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumaWall",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LumaWall", targets: ["LumaWall"])
    ],
    targets: [
        .executableTarget(
            name: "LumaWall",
            path: "Sources/LumaWall",
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "LumaWallTests",
            dependencies: ["LumaWall"],
            path: "Tests/LumaWallTests"
        )
    ]
)
