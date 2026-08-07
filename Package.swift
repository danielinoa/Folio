// swift-tools-version: 6.3
// Copyright © 2026 Daniel Inoa.

// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Folio",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Folio",
            targets: ["Folio"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Folio"
        ),
        .testTarget(
            name: "FolioTests",
            dependencies: ["Folio"]
        ),
        .testTarget(
            name: "FolioPublicAPITests",
            dependencies: ["Folio"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
