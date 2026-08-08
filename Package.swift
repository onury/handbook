// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Handbook",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Handbook", targets: ["Handbook"]),
    ],
    targets: [
        .target(name: "Handbook"),
        .testTarget(name: "HandbookTests", dependencies: ["Handbook"]),
    ]
)
