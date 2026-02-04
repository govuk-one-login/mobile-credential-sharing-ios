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
            targets: ["BluetoothTransport", "PrerequisiteGate", "CameraService", "CryptoService", "Orchestration"]
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
            dependencies: [
                "BluetoothTransport"
            ],
            path: "BluetoothTransport/Tests"
        ),
        .target(
            name: "CameraService",
            dependencies: [
                .product(name: "SwiftCBOR", package: "SwiftCBOR"),
                .product(name: "GDSCommon", package: "mobile-ios-common"),
                // TODO: DCMAW-18234 - CryptoService dependency will be removed with refactor & orchestrator
                "CryptoService"
            ],
            path: "CameraService/Sources"
        ),
        .testTarget(
            name: "CameraServiceTests",
            dependencies: [
                "CameraService"
            ],
            path: "CameraService/Tests"
        ),
        .target(
            name: "PrerequisiteGate",
            path: "PrerequisiteGate/Sources"
        ),
        .testTarget(
            name: "PrerequisiteGateTests",
            path: "PrerequisiteGate/Tests"
        ),
        .target(
            name: "CryptoService",
            dependencies: [
                .product(name: "SwiftCBOR", package: "SwiftCBOR")
            ],
            path: "CryptoService/Sources"
        ),
        .testTarget(
            name: "CryptoServiceTests",
            dependencies: [
                "CryptoService"
            ],
            path: "CryptoService/Tests"
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
            dependencies: [
                // TODO: DCMAW-18155 Remove these dependencies when introducing Orchestrator
                "BluetoothTransport",
                "CryptoService"
            ],
            path: "CredentialSharingUI/Sources"
        ),
        .testTarget(
            name: "CredentialSharingUITests",
            dependencies: [
                "CredentialSharingUI"
            ],
            path: "CredentialSharingUI/Tests"
        )
    ]
)
