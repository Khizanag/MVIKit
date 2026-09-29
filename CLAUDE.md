# CLAUDE.md — MVIKit

Model-View-Intent for SwiftUI as one dependency-free Swift package, published on the Swift Package Index. Cinematic (`Khizanag/Cinematic-iOS`) is the reference consumer.

## Rules

- Zero dependencies, ever. The pitch is "read it in one sitting" — every addition must earn its lines.
- Platform floor is Observation's: iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1. Never use an API newer than that without `@available`.
- Swift 6, `defaultIsolation(MainActor.self)`; types that cross isolation are `nonisolated` and `Sendable`.
- Every public symbol carries a doc comment — the Swift Package Index builds the DocC site from them (`.spi.yml`).
- The README's code is mirrored in `Tests/MVIKitTests/ReadmeExampleTests.swift`. Change one, change the other.
- Tests are Swift Testing. `swiftlint --strict` passes with zero violations before every commit.

## Commands

```bash
swift test
swiftlint lint --strict
xcodebuild docbuild -scheme MVIKit -destination generic/platform=macOS
```

## Releases

Semantic versioning; tags are bare (`1.0.0`, no `v`). A breaking public-API change is a major bump. After tagging, bump Cinematic's `from:` requirement and its `Package.resolved`.
