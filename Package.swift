// swift-tools-version: 6.3
// Copyright © 2026 Daniel Inoa.

import PackageDescription

let package = Package(
  name: "Folio",
  platforms: [
    .iOS(.v18)
  ],
  products: [
    .library(
      name: "Folio",
      targets: ["Folio"]
    )
  ],
  targets: [
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
