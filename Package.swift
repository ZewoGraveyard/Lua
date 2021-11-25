// swift-tools-version:5.5.0
import PackageDescription

let package = Package(
    name: "Lua",
    products: [
        .library(name: "Lua", targets: ["Lua"]),
    ],
    dependencies: [
        .package(path: "../CLua")
    ],
    targets: [
        .target(name: "Lua", dependencies: ["CLua"]),
        .testTarget(name: "LuaTests", dependencies: ["Lua"])
    ]
)
