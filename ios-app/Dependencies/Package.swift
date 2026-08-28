// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MobiIOSDependencies",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "MobiIOSDependencies",
            targets: ["MobiIOSDependencies"],
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            exact: "1.26.2",
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies",
            exact: "1.17.1",
        ),
        .package(
            url: "https://github.com/maplibre/maplibre-gl-native-distribution",
            exact: "6.27.0",
        ),
    ],
    targets: [
        .target(
            name: "MobiIOSDependencies",
            dependencies: [
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture",
                ),
                .product(
                    name: "Dependencies",
                    package: "swift-dependencies",
                ),
                .product(
                    name: "MapLibre",
                    package: "maplibre-gl-native-distribution",
                ),
            ],
        ),
    ],
)
