// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "benchmarks-flexbuffers",
    platforms: [.macOS(.v15)],
    dependencies: [
      .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.27.0"),
      .package(path: "./flatbuffers"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
      .executableTarget(
            name: "Benchmarks",
            dependencies: [
              .product(name: "Benchmark", package: "package-benchmark"),
              .product(name: "FlexBuffers", package: "flatbuffers"),
              .product(name: "FlatBuffers", package: "flatbuffers")
            ],
            path: "Benchmarks/Flexbuffers",
            resources: [.process("Resources")],
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
      ),
    ]
)
