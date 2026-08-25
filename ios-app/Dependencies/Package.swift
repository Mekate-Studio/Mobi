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
            exact: "1.25.4",
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies",
            exact: "1.12.0",
        ),
        .package(
            url: "https://github.com/maplibre/maplibre-gl-native-distribution",
            exact: "6.29.0",
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
