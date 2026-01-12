// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Strafe",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Strafe", targets: ["Strafe"])
    ],
    dependencies: [
        .package(url: "https://github.com/Kyome22/OpenMultitouchSupport", from: "3.0.3")
    ],
    targets: [
        .executableTarget(
            name: "Strafe",
            dependencies: [
                .product(name: "OpenMultitouchSupport", package: "OpenMultitouchSupport")
            ]
        )
    ]
)
