// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MobiIOSDependencies",
    platforms: [
        .iOS("26.0"),
    ],
    products: [
        .library(
            name: "MobiIOSDependencies",
            targets: ["MobiIOSDependencies"],
        ),
        .library(
            name: "MobiIOSTestDependencies",
            targets: ["MobiIOSTestDependencies"],
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            exact: "1.26.0",
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies",
            exact: "1.12.0",
        ),
        .package(url: "https://github.com/pointfreeco/swift-clocks", exact: "1.0.6"),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", exact: "1.3.2"),
        .package(
            url: "https://github.com/maplibre/maplibre-gl-native-distribution",
            exact: "6.27.0",
        ),
    ],
    targets: [
        .target(
            name: "MobiIOSTestDependencies",
            dependencies: [
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
            ],
        ),
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
