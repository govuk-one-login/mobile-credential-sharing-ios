// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HolderUI",
    platforms: [.iOS(.v16), .macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "HolderUI",
            targets: ["HolderUI"]
        )
    ],
    dependencies: [
        .package(path: "../Bluetooth"),
        .package(path: "../ISOModelsOld"),
        .package(path: "../Holder"),
        .package(path: "../SharingSecurity")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "HolderUI",
            dependencies: [
                .product(
                    name: "Bluetooth",
                    package: "Bluetooth"
                ),
                .product(
                    name: "ISOModelsOld",
                    package: "ISOModelsOld"
                ),
                .product(
                    name: "Holder",
                    package: "Holder"
                ),
                .product(
                    name: "SharingSecurity",
                    package: "SharingSecurity"
                )
            ]
        ),
        .testTarget(
            name: "HolderUITests",
            dependencies: ["HolderUI"]
        )
    ]
)
