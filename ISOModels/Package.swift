// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ISOModels",
    platforms: [.iOS(.v16), .macOS(.v15)],
    products: [
        .library(
            name: "ISOModels",
            targets: ["ISOModels"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/valpackett/SwiftCBOR",
            from: "0.5.0"
        )
    ],
    targets: [
        .target(
            name: "Utilities",
            dependencies: [
                .product(name: "SwiftCBOR", package: "SwiftCBOR")
            ]
        ),
        .target(
            name: "ISOModels",
            dependencies: [
                "Utilities",
                .product(name: "SwiftCBOR", package: "SwiftCBOR")
            ]
        ),
        .testTarget(
            name: "ISOModelsTests",
            dependencies: [
                "ISOModels",
                .product(name: "SwiftCBOR", package: "SwiftCBOR")
            ]
        )
    ]
)
