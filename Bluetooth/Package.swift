// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Bluetooth",
    platforms: [.iOS(.v16), .macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Bluetooth",
            targets: ["Bluetooth"]
        )
    ],
    dependencies: [
        .package(path: "../ISOModels")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Bluetooth",
            dependencies: [
                .product(
                    name: "ISOModels",
                    package: "ISOModels"
                )
            ]
        ),
        .testTarget(
            name: "BluetoothTests",
            dependencies: ["Bluetooth"]
        )
    ]
)
