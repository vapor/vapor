import Synchronization

/// Type to hold other types that can be mutated until the server starts, at which point
/// we'll trigger a precondition
final class FreezableType<Value: Sendable>: Sendable {
    private struct State {
        var value: Value
        var isFrozen: Bool = false
    }

    private let state: Mutex<State>

    /// Names this configuration in the precondition message, e.g. "Middleware".
    private let name: StaticString

    init(_ value: Value, name: StaticString) {
        self.state = .init(.init(value: value))
        self.name = name
    }

    /// The current value, readable whether or not the application has started.
    var value: Value {
        self.state.withLock { $0.value }
    }

    /// Changes the value, trapping if the application has already started.
    ///
    /// The check and the change happen under one lock, so a value cannot be written on the strength
    /// of a freeze state that has since moved on.
    func withValue<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        try self.state.withLock { state in
            precondition(
                !state.isFrozen,
                """
                \(self.name) cannot be changed after the application has started. \
                Configure it before calling run() or start().
                """
            )
            return try body(&state.value)
        }
    }

    /// Refuses further changes and hands back the final value.
    ///
    /// Freezing twice is harmless: a server that restarts freezes what is already frozen.
    @discardableResult
    func freeze() -> Value {
        self.state.withLock {
            $0.isFrozen = true
            return $0.value
        }
    }
}
