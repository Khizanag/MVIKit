import Foundation
import MVIKit
import Testing

/// An effect that waits for a go signal, then signals the moment it hands its
/// intent to `send`.
private struct DeliveryReducer: Reducer {
    struct State: Equatable {
        var landed = false
    }

    enum Intent: Sendable {
        case start
        case landed
        case cancel
    }

    let go: Signal
    let aboutToSend: Signal

    func reduce(_ state: inout State, _ intent: Intent) -> Effect<Intent> {
        switch intent {
        case .start:
            return .run(id: "work") { [go, aboutToSend] send in
                while !go.raised {
                    try? await Task.sleep(for: .milliseconds(1))
                }
                aboutToSend.raise()
                await send(.landed)
            }

        case .landed:
            state.landed = true
            return .none

        case .cancel:
            return .cancel("work")
        }
    }
}

/// A flag one thread raises and another polls.
nonisolated private final class Signal: @unchecked Sendable {
    private let lock = NSLock()
    private var isRaised = false

    var raised: Bool {
        lock.withLock { isRaised }
    }

    func raise() {
        lock.withLock { isRaised = true }
    }
}

@MainActor
struct SendTests {
    @Test("An intent is dropped when its effect is cancelled while delivery waits for the main actor")
    func cancelDuringDeliveryDropsIntent() async throws {
        let go = Signal()
        let aboutToSend = Signal()
        let store = Store(
            initialState: DeliveryReducer.State(),
            reducer: DeliveryReducer(go: go, aboutToSend: aboutToSend),
        )

        store.send(.start)
        // Let the effect start and park off the main actor.
        try await Task.sleep(for: .milliseconds(20))
        // From here the main actor stays busy until the cancel, so the effect
        // reaches `send` on another thread and its delivery queues behind it.
        go.raise()
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while !aboutToSend.raised, clock.now < deadline {}
        try #require(aboutToSend.raised)
        let margin = clock.now.advanced(by: .milliseconds(20))
        while clock.now < margin {}

        store.send(.cancel)
        await store.settle()

        #expect(!store.state.landed)
    }
}
