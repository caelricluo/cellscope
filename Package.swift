// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CellCounterCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "CellCounterCore", targets: ["CellCounterCore"])],
    targets: [
        .target(name: "CellCounterCore"),
        .testTarget(name: "CellCounterCoreTests", dependencies: ["CellCounterCore"])
    ]
)
