// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CredentialSharing",
    platforms: [.iOS(.v16), .macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CredentialSharing",
            targets: ["BluetoothTransport", "PermissionsGate", "CameraService", "CryptoService", "ISOModels", "Orchestration"]
        ),
        .library(
            name: "CredentialSharingUI",
            targets: ["CredentialSharingUI"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/beatt83/SwiftCBOR",
            from: "0.5.1"
        ),
        .package(
            url: "https://github.com/govuk-one-login/mobile-ios-common",
            from: "2.19.1"
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BluetoothTransport",
            path: "BluetoothTransport/Sources"
        ),
        .testTarget(
            name: "BluetoothTransportTests",
            path: "BluetoothTransport/Tests"
        ),
        .target(
            name: "CameraService",
            dependencies: [
                .product(name: "SwiftCBOR", package: "SwiftCBOR"),
                .product(name: "GDSCommon", package: "mobile-ios-common"),
                // TODO: DCMAW-18234 - ISOModels dependency will be removed with refactor & orchestrator
                "ISOModels"
            ],
            path: "CameraService/Sources"
        ),
        .testTarget(
            name: "CameraServiceTests",
            path: "CameraService/Tests"
        ),
        .target(
            name: "PermissionsGate",
            path: "PermissionsGate/Sources"
        ),
        .testTarget(
            name: "PermissionsGateTests",
            path: "PermissionsGate/Tests"
        ),
        .target(
            name: "CryptoService",
            path: "CryptoService/Sources"
        ),
        .testTarget(
            name: "CryptoServiceTests",
            path: "CryptoService/Tests"
        ),
        .target(
            name: "ISOModels",
            dependencies: [
                .product(name: "SwiftCBOR", package: "SwiftCBOR")
            ],
            path: "ISOModels/Sources",
        ),
        .testTarget(
            name: "ISOModelsTests",
            dependencies: [
                "ISOModels",
                .product(name: "SwiftCBOR", package: "SwiftCBOR")
            ],
            path: "ISOModels/Tests"
        ),
        .target(
            name: "Orchestration",
            path: "Orchestration/Sources"
        ),
        .testTarget(
            name: "OrchestrationTests",
            path: "Orchestration/Tests"
        ),
        .target(
            name: "CredentialSharingUI",
            path: "CredentialSharingUI/Sources"
        ),
        .testTarget(
            name: "CredentialSharingUITests",
            path: "CredentialSharingUI/Tests"
        )
    ]
)
