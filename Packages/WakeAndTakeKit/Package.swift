// swift-tools-version: 6.2

import PackageDescription

/// Settings every target shares: Swift 6 mode (from the tools version) plus the same
/// "approachable concurrency" features the app target enables.
let commonSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

/// UI modules run on the main actor by default, like the app target.
let mainActorSettings = commonSettings + [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "WakeAndTakeKit",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Platform", targets: ["Platform"]),
        .library(name: "MockData", targets: ["MockData"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "CustomerFeatures", targets: ["CustomerFeatures"]),
    ],
    targets: [
        .target(name: "Domain", swiftSettings: commonSettings),
        .target(name: "Platform", dependencies: ["Domain"], swiftSettings: commonSettings),
        .target(
            name: "MockData",
            dependencies: ["Domain", "Platform"],
            resources: [.process("Resources")],
            swiftSettings: commonSettings
        ),
        .target(name: "DesignSystem", dependencies: ["Domain"], swiftSettings: mainActorSettings),
        .target(
            name: "CustomerFeatures",
            dependencies: ["Domain", "DesignSystem", "Platform"],
            swiftSettings: mainActorSettings
        ),

        .testTarget(name: "DomainTests", dependencies: ["Domain"], swiftSettings: commonSettings),
        .testTarget(name: "PlatformTests", dependencies: ["Platform"], swiftSettings: commonSettings),
        .testTarget(name: "MockDataTests", dependencies: ["MockData"], swiftSettings: commonSettings),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"], swiftSettings: mainActorSettings),
        .testTarget(
            name: "CustomerFeaturesTests",
            dependencies: ["CustomerFeatures"],
            swiftSettings: mainActorSettings
        ),
    ]
)
