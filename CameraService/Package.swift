// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CameraService",
    platforms: [.iOS(.v16), .macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CameraService",
            targets: ["CameraService"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/govuk-one-login/mobile-ios-common",
            from: "2.19.1"
        ),
        .package(path: "../ISOModels")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CameraService",
            dependencies: [
                .product(name: "GDSCommon",
                         package: "mobile-ios-common"),
                .product(
                    name: "ISOModels",
                    package: "ISOModels"
                )
            ]
        ),
        .testTarget(
            name: "CameraServiceTests",
            dependencies: [
                "CameraService",
                .product(
                    name: "ISOModels",
                    package: "ISOModels"
                )
            ]
        )
    ]
)
