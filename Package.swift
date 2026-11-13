// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "cellscope",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "cellscopeCore", targets: ["cellscopeCore"])],
    targets: [
        .target(name: "cellscopeCore"),
        .testTarget(name: "cellscopeCoreTests", dependencies: ["cellscopeCore"])
    ]
)
