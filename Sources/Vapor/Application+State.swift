import Synchronization

extension Application {
    /// Where the application is in its lifecycle.
    public enum State: Sendable, Equatable, CustomStringConvertible {
        /// Built, and accepting configuration.
        case configuring
        /// Running the `willBoot` and `didBoot` lifecycle handlers.
        case booting
        /// Booted, and still accepting configuration: the freeze happens at start, so a provider's
        /// `didBoot` may register middleware, routes or services.
        case booted
        /// Configuration has been frozen and the services are coming up.
        case starting
        /// The services are running.
        case started
        /// Running the `shutdown` lifecycle handlers.
        case shuttingDown
        /// Shut down. Terminal.
        case shutdown

        public var description: String {
            switch self {
            case .configuring: "configuring"
            case .booting: "booting"
            case .booted: "booted"
            case .starting: "starting"
            case .started: "started"
            case .shuttingDown: "shutting down"
            case .shutdown: "shut down"
            }
        }
    }

    /// Asking an application to do something its lifecycle does not allow.
    public struct LifecycleError: Error, Equatable, CustomStringConvertible {
        /// What was attempted, e.g. "start".
        public let operation: String

        /// The state that made it impossible.
        public let state: State

        public var description: String {
            "Cannot \(self.operation) an application that is \(self.state)."
        }
    }
}

/// Tracks the application's lifecycle and guards its transitions.
///
/// Transitions a caller can reach from outside — booting an application that has shut down, starting
/// one that is already running — throw ``Application/LifecycleError``. Transitions only Vapor's own
/// code can drive, such as finishing a start that was never begun, are programmer errors and trap.
final class ApplicationStateMachine: Sendable {
    private let state: Mutex<Application.State>

    init() {
        self.state = .init(.configuring)
    }

    var current: Application.State {
        self.state.withLock { $0 }
    }

    /// Whether configuration may still change.
    ///
    /// Configuration stays open through boot so that a provider's `willBoot` or `didBoot` can
    /// register middleware, routes and services. It closes on entering ``Application/State/starting``.
    var isConfigurable: Bool {
        switch self.current {
        case .configuring, .booting, .booted: true
        case .starting, .started, .shuttingDown, .shutdown: false
        }
    }

    /// Claims the right to boot.
    ///
    /// - Returns: `false` if the application is already booted or booting, in which case `boot()`
    ///   has nothing to do. Booting is idempotent because `withLifecycle` boots unconditionally and
    ///   the testing helpers may have booted already.
    func beginBoot() throws -> Bool {
        try self.state.withLock { state in
            switch state {
            case .configuring:
                state = .booting
                return true
            case .booting, .booted, .starting, .started:
                return false
            case .shuttingDown, .shutdown:
                throw Application.LifecycleError(operation: "boot", state: state)
            }
        }
    }

    func finishBoot() {
        self.state.withLock { state in
            precondition(state == .booting, "finishBoot() while \(state)")
            state = .booted
        }
    }

    /// Returns the application to ``Application/State/configuring`` after a boot that threw.
    ///
    /// The old flag was set before the handlers ran, so a failed boot left the application marked
    /// booted and a retry silently did nothing.
    func abandonBoot() {
        self.state.withLock { state in
            precondition(state == .booting, "abandonBoot() while \(state)")
            state = .configuring
        }
    }

    /// Claims the right to start, closing configuration.
    func beginStart() throws {
        try self.state.withLock { state in
            switch state {
            case .configuring, .booted:
                state = .starting
            case .booting, .starting, .started, .shuttingDown, .shutdown:
                throw Application.LifecycleError(operation: "start", state: state)
            }
        }
    }

    func finishStart() {
        self.state.withLock { state in
            precondition(state == .starting, "finishStart() while \(state)")
            state = .started
        }
    }

    /// Claims the right to shut down.
    ///
    /// - Returns: `false` if a shutdown has already happened or is in flight. A caller arriving
    ///   during one returns immediately rather than waiting for it to finish.
    func beginShutdown() -> Bool {
        self.state.withLock { state in
            switch state {
            case .shuttingDown, .shutdown:
                return false
            case .configuring, .booting, .booted, .starting, .started:
                state = .shuttingDown
                return true
            }
        }
    }

    func finishShutdown() {
        self.state.withLock { state in
            precondition(state == .shuttingDown, "finishShutdown() while \(state)")
            state = .shutdown
        }
    }
}
