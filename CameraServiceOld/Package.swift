// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CameraServiceOld",
    platforms: [.iOS(.v16), .macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CameraServiceOld",
            targets: ["CameraServiceOld"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/govuk-one-login/mobile-ios-common",
            from: "2.19.1"
        ),
        .package(path: "../ISOModelsOld")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CameraServiceOld",
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
            name: "CameraServiceOldTests",
            dependencies: [
                "CameraServiceOld",
                .product(
                    name: "ISOModelsOld",
                    package: "ISOModelsOld"
                )
            ] display):CameraServiceOld/Package.swift
        )
    ]
)
