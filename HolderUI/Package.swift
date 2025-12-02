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
        .package(path: "../Bluetooth")
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
                )
            ]
        ),
        .testTarget(
            name: "HolderUITests",
            dependencies: ["HolderUI"]
        )
    ]
)
