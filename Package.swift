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
            path: "ISOModels/Sources"
        ),
        .testTarget(
            name: "ISOModelsTests",
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
