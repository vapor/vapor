import Synchronization

/// A value that may be configured until the application starts, and is read-only afterwards.
///
/// Uses the ``Application/State`` to determine if writes are allowed. If the application is
/// in a state where writes are not allowed, such as being started already. If this is the case
/// then a precondition is triggered. Reads are always allowed.
final class FreezableType<Value: Sendable>: Sendable {
    private let storage: Mutex<Value>

    /// The lifecycle that decides whether changes are still allowed.
    private let lifecycle: ApplicationStateMachine

    /// Names this configuration in the precondition message, e.g. "Middlewares".
    private let name: StaticString

    init(_ value: Value, name: StaticString, lifecycle: ApplicationStateMachine) {
        self.storage = .init(value)
        self.name = name
        self.lifecycle = lifecycle
    }

    /// The current value, readable whether or not the application has started.
    var value: Value {
        self.storage.withLock { $0 }
    }

    /// Changes the value, trapping if the application has already started. Prevents being used for reading
    /// to avoid accessing when you shouldn't be. Uses the lifecycle of the application to ensure values
    /// can be mutated
    func withValue(_ body: (inout Value) throws -> Void) rethrows {
        try self.storage.withLock { value in
            precondition(
                self.lifecycle.isConfigurable,
                """
                \(self.name) cannot be changed once the application is \(self.lifecycle.current). \
                Configure it before calling run() or start().
                """
            )
            try body(&value)
        }
    }
}
