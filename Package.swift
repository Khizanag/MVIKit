// swift-tools-version: 6.2
// 6.2 is the floor: `defaultIsolation`, `@concurrent`, and the approachable
// concurrency upcoming features need it. The platform floor is set by
// Observation (`@Observable`), not by anything newer.
import PackageDescription

let package = Package(
    name: "MVIKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "MVIKit", targets: ["MVIKit"]),
    ],
    targets: [
        .target(
            name: "MVIKit",
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ],
        ),
        .testTarget(
            name: "MVIKitTests",
            dependencies: ["MVIKit"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ],
        ),
    ],
    swiftLanguageModes: [.v6],
)
