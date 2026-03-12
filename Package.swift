// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CredentialSharing",
    platforms: [
        .iOS(.v16 ),
        .macOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CredentialSharing",
            targets: [
                "SharingBluetoothTransport",
                "SharingPrerequisiteGate",
                "SharingCameraService",
                "SharingCryptoService",
                "SharingOrchestration"
            ]
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
            name: "SharingBluetoothTransport",
            path: "SharingBluetoothTransport/Sources"
        ),
        .testTarget(
            name: "SharingBluetoothTransportTests",
            dependencies: ["SharingBluetoothTransport"],
            path: "SharingBluetoothTransport/Tests"
        ),
        .target(
            name: "SharingCameraService",
            dependencies: [
                .product(
                    name: "SwiftCBOR",
                    package: "SwiftCBOR"
                ),
                .product(
                    name: "GDSCommon",
                    package: "mobile-ios-common"
                ),
                // TODO: DCMAW-18234 - CryptoService dependency will be removed with refactor & orchestrator
                "SharingCryptoService"
            ],
            path: "SharingCameraService/Sources"
        ),
        .testTarget(
            name: "SharingCameraServiceTests",
            dependencies: ["SharingCameraService"],
            path: "SharingCameraService/Tests"
        ),
        .target(
            name: "SharingPrerequisiteGate",
            dependencies: ["SharingBluetoothTransport"],
            path: "SharingPrerequisiteGate/Sources"
        ),
        .testTarget(
            name: "SharingPrerequisiteGateTests",
            dependencies: ["SharingPrerequisiteGate"],
            path: "SharingPrerequisiteGate/Tests"
        ),
        .target(
            name: "SharingCryptoService",
            dependencies: [
                .product(
                    name: "SwiftCBOR",
                    package: "SwiftCBOR"
                )
            ],
            path: "SharingCryptoService/Sources"
        ),
        .testTarget(
            name: "SharingCryptoServiceTests",
            dependencies: [
                "SharingCryptoService",
                "CredentialSharingUI",
                "SharingBluetoothTransport"
            ],
            path: "SharingCryptoService/Tests"
        ),
        .target(
            name: "SharingOrchestration",
            dependencies: [
                "SharingPrerequisiteGate",
                "SharingCryptoService"
            ],
            path: "SharingOrchestration/Sources"
        ),
        .testTarget(
            name: "SharingOrchestrationTests",
            dependencies: ["SharingOrchestration"],
            path: "SharingOrchestration/Tests"
        ),
        .target(
            name: "CredentialSharingUI",
            dependencies: [
                // TODO: DCMAW-18155 Remove these dependencies when introducing Orchestrator
                "SharingBluetoothTransport",
                "SharingCryptoService",
                "SharingOrchestration"
            ],
            path: "CredentialSharingUI/Sources"
        ),
        .testTarget(
            name: "CredentialSharingUITests",
            dependencies: ["CredentialSharingUI"],
            path: "CredentialSharingUI/Tests"
        )
    ]
)
