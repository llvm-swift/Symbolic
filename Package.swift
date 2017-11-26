// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Symbolic",
    products: [
        .library(
            name: "Symbolic",
            targets: ["Symbolic"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "GlibcDlfcnShim",
            dependencies: []),
        .target(
            name: "Symbolic",
            dependencies: ["GlibcDlfcnShim"]),
        .testTarget(
            name: "SymbolicTests",
            dependencies: ["Symbolic"]),
    ]
)
