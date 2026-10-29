// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CredentialSharing",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16 ),
        .macOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CredentialSharing",
            targets: [
                "CoseVerification",
                "ExchangeFormat",
                "ReaderAuthentication",
                "SharingBluetoothTransport",
                "SharingPrerequisiteGate",
                "SharingCameraService",
                "SharingCryptoService",
                "SharingOrchestration",
                "SharingLogging"
            ]
        ),
        .library(
            name: "CredentialSharingUI",
            targets: ["CredentialSharingUI"]
        ),
        .library(
            name: "CredentialSharingTestUtilities",
            targets: ["CredentialSharingTestUtilities"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/valpackett/SwiftCBOR",
            from: "0.6.0"
        ),
        .package(
            url: "https://github.com/govuk-one-login/mobile-ios-common",
            from: "2.19.1"
        ),
        .package(
            url: "https://github.com/govuk-one-login/mobile-ios-logging",
            from: "7.0.2"
        ),
        .package(
            url: "https://github.com/govuk-one-login/mobile-ios-ui",
            from: "2.7.3"
        ),
        .package(
            url: "https://github.com/apple/swift-certificates",
            from: "1.15.0"
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CoseVerification",
            dependencies: [
                .product(name: "SwiftCBOR", package: "SwiftCBOR"),
                .product(name: "X509", package: "swift-certificates")
            ],
            path: "CoseVerification/Sources"
        ),
        .testTarget(
            name: "CoseVerificationTests",
            dependencies: ["CoseVerification"],
            path: "CoseVerification/Tests"
        ),
        .target(
            name: "ExchangeFormat",
            dependencies: [
                .product(name: "SwiftCBOR", package: "SwiftCBOR")
            ],
            path: "ExchangeFormat/Sources"
        ),
        .testTarget(
            name: "ExchangeFormatTests",
            dependencies: ["ExchangeFormat"],
            path: "ExchangeFormat/Tests"
        ),
        .target(
            name: "ReaderAuthentication",
            dependencies: [
                "CoseVerification",
                "ExchangeFormat",
                .product(name: "X509", package: "swift-certificates")
            ],
            path: "ReaderAuthentication/Sources"
        ),
        .testTarget(
            name: "ReaderAuthenticationTests",
            dependencies: [
                "ReaderAuthentication",
                "CoseVerification",
                .product(name: "SwiftCBOR", package: "SwiftCBOR"),
                .product(name: "X509", package: "swift-certificates")
            ],
            path: "ReaderAuthentication/Tests"
        ),
        .target(
            name: "SharingBluetoothTransport",
            dependencies: ["SharingLogging"],
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
                )
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
            dependencies: ["SharingBluetoothTransport", "SharingCameraService", "SharingLogging"],
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
                ), "SharingLogging"
            ],
            path: "SharingCryptoService/Sources"
        ),
        .testTarget(
            name: "SharingCryptoServiceTests",
            dependencies: [
                "SharingCryptoService",
                "CredentialSharingUI",
                "SharingBluetoothTransport",
                "SharingLogging"
            ],
            path: "SharingCryptoService/Tests"
        ),
        .target(
            name: "SharingOrchestration",
            dependencies: [
                "SharingPrerequisiteGate",
                "SharingCryptoService",
                "SharingLogging",
                "ReaderAuthentication",
                "ExchangeFormat",
                .product(name: "Logging", package: "mobile-ios-logging"),
                .product(name: "GDSAnalytics", package: "mobile-ios-logging"),
                .product(name: "X509", package: "swift-certificates")
            ],
            path: "SharingOrchestration/Sources"
        ),
        .testTarget(
            name: "SharingOrchestrationTests",
            dependencies: [
                "SharingOrchestration",
                "CredentialSharingTestUtilities",
                .product(name: "X509", package: "swift-certificates")
            ],
            path: "SharingOrchestration/Tests"
        ),
        .target(
            name: "CredentialSharingTestUtilities",
            dependencies: [
                "SharingOrchestration",
                "SharingPrerequisiteGate",
                "SharingCryptoService",
                .product(name: "Logging", package: "mobile-ios-logging"),
                .product(name: "X509", package: "swift-certificates")
            ],
            path: "CredentialSharingTestUtilities/Sources",
            // SE-0560 (configuration-conditional target dependencies) will let us
            // depend on this target only in debug builds. Until then, defining DEBUG
            // only for the debug configuration — combined with the `#if DEBUG` (enforced by linter)
            // guard wrapping every file in this target — ensures none of this mock code is
            // compiled into release builds.
            // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0560-swiftpm-build-configuration-conditional-target-dependencies.md
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "CredentialSharingUI",
            dependencies: [
                // TODO: DCMAW-18155 Remove these dependencies when introducing Orchestrator
                "SharingBluetoothTransport",
                "SharingCryptoService",
                "SharingOrchestration",
                "SharingLogging",
                "CredentialSharingTestUtilities",
                .product(name: "DesignSystem", package: "mobile-ios-ui"),
                .product(name: "GDSAnalytics", package: "mobile-ios-logging"),
                .product(name: "X509", package: "swift-certificates")
            ],
            path: "CredentialSharingUI/Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CredentialSharingUITests",
            dependencies: [
                "CredentialSharingUI",
                "CredentialSharingTestUtilities",
                "SharingLogging",
                .product(name: "Logging", package: "mobile-ios-logging")
            ],
            path: "CredentialSharingUI/Tests"
        ),
        .testTarget(
            name: "ISO18013-6Tests",
            dependencies: ["SharingCryptoService", "SharingLogging"],
            path: "ISO18013-6Tests"
        ),
        .target(
            name: "SharingLogging",
            dependencies: [
                .product(name: "Logging", package: "mobile-ios-logging"),
                .product(name: "GDSAnalytics", package: "mobile-ios-logging")
            ],
            path: "SharingLogging/Sources"
        ),
        .testTarget(
            name: "SharingLoggingTests",
            dependencies: [
                "SharingLogging",
                .product(name: "GDSAnalytics", package: "mobile-ios-logging")
            ],
            path: "SharingLogging/Tests"
        )
    ]
)
