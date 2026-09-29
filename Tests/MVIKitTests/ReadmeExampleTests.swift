import MVIKit
import SwiftUI
import Testing

private enum SearchError: Error, Equatable {
    case offline
}

private struct SearchReducer: Reducer {
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

private struct SearchView: View {
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

// The README's example, compiled and exercised so the docs cannot drift.
@MainActor
struct ReadmeExampleTests {
    @Test("Typing a query moves results to loading")
    func typingStartsALoad() {
        var state = SearchReducer.State()
        _ = SearchReducer { _ in [] }.reduce(&state, .queryChanged("dune"))
        #expect(state.results == .loading)
    }

    @Test("A settled search lands its results")
    func searchLoadsResults() async {
        let store = Store(initialState: .init(), reducer: SearchReducer { _ in ["Dune"] })
        store.send(.queryChanged("dune"))
        await store.settle()
        #expect(store.state.results == .loaded(["Dune"]))
    }

    @Test("A newer query replaces the in-flight search")
    func newQueryReplacesOldSearch() async {
        let store = Store(initialState: .init(), reducer: SearchReducer { query in [query] })
        store.send(.queryChanged("du"))
        store.send(.queryChanged("dune"))
        await store.settle()
        #expect(store.state.results == .loaded(["dune"]))
    }

    @Test("Failures surface as the typed domain error")
    func failureIsTyped() async {
        let store = Store(initialState: .init(), reducer: SearchReducer { _ throws(SearchError) in throw .offline })
        store.send(.queryChanged("dune"))
        await store.settle()
        #expect(store.state.results == .failed(.offline))
    }
}
