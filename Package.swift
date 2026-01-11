// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TabTap",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TabTap", targets: ["TabTap"])
    ],
    dependencies: [
        .package(url: "https://github.com/Kyome22/OpenMultitouchSupport", from: "3.0.3")
    ],
    targets: [
        .executableTarget(
            name: "TabTap",
            dependencies: [
                .product(name: "OpenMultitouchSupport", package: "OpenMultitouchSupport")
            ]
        )
    ]
)
