// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "ResourceGenerator",
  platforms: [.macOS(.v13)],
  products: [
    .plugin(name: "ResourceGeneratorPlugin", targets: ["ResourceGeneratorPlugin"]),
    .executable(name: "resource-generator", targets: ["resource-generator"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    .package(url: "https://github.com/kylef/PathKit.git", from: "1.0.1"),
    .package(
      url: "https://github.com/stencilproject/Stencil.git", from: "0.15.1"),
    .package(
      url: "https://github.com/SwiftGen/StencilSwiftKit.git", from: "2.10.0"),
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
  ],
  targets: [
    .executableTarget(
      name: "ResourceGenerator",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "PathKit",
        "Stencil",
        "StencilSwiftKit",
        "Yams",
      ],
      path: "Sources",
      resources: [
        .copy("Templates")
      ]
    ),
    .plugin(
      name: "ResourceGeneratorPlugin",
      capability: .command(
        intent: .custom(
          verb: "resource-generate",
          description: "리소스 코드 자동 생성"
        )
      ),
      dependencies: ["resource-generator"],
      path: "Plugins/ResourceGeneratorPlugin"
    ),
    // Tools
    .executableTarget(
      name: "resource-generator",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "PathKit",
        "Stencil",
        "StencilSwiftKit",
        "Yams",
      ],
      path: "Tools/resource-generator"
    )
  ]
)
