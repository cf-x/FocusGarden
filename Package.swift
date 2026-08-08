// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FocusGarden",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FocusGarden", targets: ["FocusGarden"]),
        .executable(name: "FocusGardenGuardian", targets: ["FocusGardenGuardian"])
    ],
    targets: [
        .executableTarget(
            name: "FocusGarden",
            path: "Sources/FocusGarden"
        ),
        .executableTarget(
            name: "FocusGardenGuardian",
            path: "Sources/FocusGardenGuardian"
        )
    ]
)
