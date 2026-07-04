// swift-tools-version:6.1.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iap",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "iap",
            type: .static,
            targets: ["iap"]),
    ],
    dependencies: [
        .package(name: "Tauri", path: "../.tauri/tauri-api")
    ],
    targets: [
        .target(
            name: "iap",
            dependencies: [
                .byName(name: "Tauri")
            ],
            path: "Sources",
            linkerSettings: [
                .linkedFramework("StoreKit"),
                .linkedFramework("Foundation")
            ]
        )
    ]
)
