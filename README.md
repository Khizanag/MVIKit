# MVIKit

Model-View-Intent for SwiftUI in about 270 lines. MVIKit gives you a unidirectional data flow loop: a pure reducer, effects as data, switch-latest cancellation, and an `@Observable` store. It has no dependencies, is built for Swift 6 strict concurrency, and is small enough to read in one sitting.

[![CI](https://github.com/Khizanag/MVIKit/actions/workflows/ci.yml/badge.svg)](https://github.com/Khizanag/MVIKit/actions/workflows/ci.yml)
[![Swift versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FKhizanag%2FMVIKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Khizanag/MVIKit)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FKhizanag%2FMVIKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/Khizanag/MVIKit)
[![Documentation](https://img.shields.io/badge/docs-Swift%20Package%20Index-F05138)](https://swiftpackageindex.com/Khizanag/MVIKit/documentation/mvikit)
![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey)

**See it in a real app:** [Cinematic](https://github.com/Khizanag/Cinematic-iOS) is a complete iOS app built on MVIKit and Clean Architecture. It covers debounced search, pull-to-refresh, offline caching, deep links and a full test suite.

## Contents

- [Why MVIKit](#why-mvikit)
- [Installation](#installation)
- [Quick start](#quick-start)
- [The five types](#the-five-types)
- [Testing](#testing)
- [MVIKit, TCA, or plain MVVM](#mvikit-tca-or-plain-mvvm)
- [Requirements](#requirements)

## Why MVIKit

In MVI, the view never changes state. It sends an **intent** that describes what happened. A pure **reducer** applies the intent to the **state** and returns an **effect** that describes any async work. When that work finishes, its result comes back as another intent. There is one loop, it runs in one direction, and nothing else can change state.

```text
View ──send(intent)──▶ Store ──reduce──▶ State ──▶ View
                         │                  ▲
                         └──Effect──async───┘ (as new intents)
```

The loop gives you three guarantees:

- **Every state change has a named cause.** The reducer is the only place state changes, so it is a complete record of why the screen looks the way it does.
- **Every transition is testable without UI.** Reducers are pure functions of `(inout State, Intent)`, so you assert whole states value for value.
- **Stale async results can't overwrite fresh ones.** Give an effect an `EffectID` and starting it again cancels the run in flight (switch-latest), which is exactly what search-as-you-type and pull-to-refresh need.

## Installation

Add the package in Xcode with **File → Add Package Dependencies…** and the URL `https://github.com/Khizanag/MVIKit`. Or declare it in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Khizanag/MVIKit", from: "1.0.1"),
],
targets: [
    .target(
        name: "MyFeature",
        dependencies: [
            .product(name: "MVIKit", package: "MVIKit"),
        ],
    ),
],
```

## Quick start

A debounced, cancellable search screen. First, the state, the intents, and the reducer:

```swift
import MVIKit

enum SearchError: Error, Equatable {
    case offline
}

struct SearchReducer: Reducer {
    struct State: Equatable {
        var query = ""
        var results: LoadingPhase<[String], SearchError> = .idle
    }

    enum Intent: Sendable {
        case queryChanged(String)
        case resultsLoaded([String])
        case searchFailed(SearchError)
    }

    let search: @Sendable (String) async throws(SearchError) -> [String]

    func reduce(_ state: inout State, _ intent: Intent) -> Effect<Intent> {
        switch intent {
        case let .queryChanged(query):
            state.query = query
            guard !query.isEmpty else {
                state.results = .idle
                return .cancel("search")
            }
            state.results = .loading
            return .run(id: "search") { [search] send in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                do throws(SearchError) {
                    let titles = try await search(query)
                    await send(.resultsLoaded(titles))
                } catch {
                    await send(.searchFailed(error))
                }
            }

        case let .resultsLoaded(titles):
            state.results = .loaded(titles)
            return .none

        case let .searchFailed(error):
            state.results = .failed(error)
            return .none
        }
    }
}
```

Every keystroke restarts the `"search"` effect, so the earlier sleep is cancelled and only the latest query reaches the network. That one `id:` is the whole debounce.

Then the view. It reads `store.state` and talks only through intents:

```swift
import MVIKit
import SwiftUI

struct SearchView: View {
    @State private var store: Store<SearchReducer>

    init(search: @escaping @Sendable (String) async throws(SearchError) -> [String]) {
        _store = State(initialValue: Store(initialState: .init(), reducer: SearchReducer(search: search)))
    }

    var body: some View {
        List(store.state.results.value ?? [], id: \.self) { title in
            Text(title)
        }
        .searchable(text: store.binding(\.query) { .queryChanged($0) })
    }
}
```

`binding(_:send:)` bridges APIs that need a `Binding`, such as `searchable` and `TextField`. Writes still go through the reducer.

## The five types

| Type | Role |
|---|---|
| `Reducer` | The pure state machine: `reduce(_ state: inout State, _ intent: Intent) -> Effect<Intent>` |
| `Effect` | Async work as data: `.none`, `.run(id:_:)`, `.cancel(_:)`, `.merge(_:)` |
| `Send` | The only channel from an effect back into the loop. Main-actor, and it drops intents after cancellation |
| `Store` | The `@Observable` loop driver, with `send(_:)`, `binding(_:send:)`, and `settle()` for awaiting effects |
| `LoadingPhase` | `idle`, `loading`, `loaded`, `failed` with a typed failure. Use `Never` for loads that can't fail |

The [API documentation](https://swiftpackageindex.com/Khizanag/MVIKit/documentation/mvikit) covers each one.

## Testing

Test a reducer by calling `reduce` and checking the state. No store, no UI, no waiting:

```swift
@Test func typingStartsALoad() {
    var state = SearchReducer.State()
    _ = SearchReducer { _ in [] }.reduce(&state, .queryChanged("dune"))
    #expect(state.results == .loading)
}
```

To test the whole loop, including effects, drive a real store and `await settle()`. It suspends until every effect has finished, including effects started by the intents those effects send:

```swift
@Test func newQueryReplacesOldSearch() async {
    let store = Store(initialState: .init(), reducer: SearchReducer { query in [query] })
    store.send(.queryChanged("du"))
    store.send(.queryChanged("dune"))
    await store.settle()
    #expect(store.state.results == .loaded(["dune"]))
}
```

`settle()` also connects the loop to SwiftUI's `.refreshable`: send a refresh intent, then `await store.settle()`.

The examples above are compiled and run as part of this package's own tests, so they can't go out of date.

## MVIKit, TCA, or plain MVVM

| Choose | When |
|---|---|
| **An `@Observable` model (MV/MVVM)** | A screen has one source of truth and little async logic |
| **MVIKit** | State has races, cancellation, or several sources to reconcile, and you want the guarantees without a framework |
| **[TCA](https://github.com/pointfreeco/swift-composable-architecture)** | A large app needs composable features, dependency management, and exhaustive test tooling, and the dependency is worth it |

MVIKit is the smallest thing that makes the MVI guarantees hold. Read it before you adopt a framework, so you know exactly what the framework adds.

## Requirements

- Swift 6.2 or later (Xcode 26 or later)
- iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1

MVIKit builds with `defaultIsolation(MainActor.self)` in Swift 6 language mode. The value types that cross isolation (`Effect`, `Send`, `EffectID`, `LoadingPhase`) are `nonisolated` and `Sendable`.

## License

MIT. See [LICENSE](LICENSE).
