import NIOConcurrencyHelpers

public final class Routes: RoutesBuilder, CustomStringConvertible, Sendable {
    public var all: [Route] {
        get {
            self.sendableBox.withLockedValue { box in
                box.all
            }
        }
        set {
            self.sendableBox.withLockedValue { box in
                precondition(!box.isFrozen, Self.frozenMessage("Routes"))
                box.all = newValue
            }
        }
    }
    
    /// Default value used by `HTTPBodyStreamStrategy.collect` when `maxSize` is `nil`.
    public var defaultMaxBodySize: ByteCount {
        get {
            self.sendableBox.withLockedValue { $0.defaultMaxBodySize }
        }
        set {
            self.sendableBox.withLockedValue { $0.defaultMaxBodySize = newValue }
        }
    }
    
    /// Default routing behavior of `DefaultResponder` is case-sensitive; configure to `true` prior to
    /// Application start handle `Constant` `PathComponents` in a case-insensitive manner.
    public var caseInsensitive: Bool {
        get {
            self.sendableBox.withLockedValue { $0.caseInsensitive }
        }
        set {
            self.sendableBox.withLockedValue {
                precondition(!$0.isFrozen, Self.frozenMessage("Case sensitivity"))
                $0.caseInsensitive = newValue
            }
        }
    }

    public var description: String {
        self.all.description
    }
    
    struct SendableBox: Sendable {
        var all: [Route]
        var defaultMaxBodySize: ByteCount
        var caseInsensitive: Bool
        /// Set as the application starts, once the router has been built from these routes.
        var isFrozen: Bool = false
    }

    private static func frozenMessage(_ what: String) -> String {
        """
        \(what) cannot be changed after the application has started. \
        Configure it before calling run() or start().
        """
    }
    
    let sendableBox: NIOLockedValueBox<SendableBox>

    public init() {
        let box = SendableBox(all: [], defaultMaxBodySize: "16kb", caseInsensitive: false)
        self.sendableBox = .init(box)
    }

    public func add(_ route: Route) {
        self.sendableBox.withLockedValue {
            precondition(!$0.isFrozen, Self.frozenMessage("Routes"))
            $0.all.append(route)
        }
    }

    /// Refuses further changes to the routes and to case sensitivity.
    ///
    /// Both are baked into the router when it is built at startup, so changing either afterwards
    /// would be accepted and then never used. ``defaultMaxBodySize`` is deliberately not covered:
    /// it is read afresh on every request rather than baked in, so changing it after start does
    /// take effect.
    ///
    /// Freezing twice is harmless, so a server that restarts is fine.
    func freeze() {
        self.sendableBox.withLockedValue { $0.isFrozen = true }
    }
}

extension Application: RoutesBuilder {
    public func add(_ route: Route) {
        self.routes.add(route)
    }
}
