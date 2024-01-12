import NIOConcurrencyHelpers

public final class Routes: RoutesBuilder, CustomStringConvertible, Sendable {
    @available(*, deprecated, message: "Use `sendableAll` instead")
    public var all: [Route] {
        get {
            self.sendableBox.withLockedValue { box in
                box.all.map { Route(sendableRoute: $0) }
            }
        }
        set {
            self.sendableBox.withLockedValue { box in
                box.all = newValue.map { $0.sendableRoute }
            }
        }
    }
    
    public var sendableAll: [SendableRoute] {
        get {
            self.sendableBox.withLockedValue { box in
                box.all
            }
        }
        set {
            self.sendableBox.withLockedValue { box in
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
            self.sendableBox.withLockedValue { $0.caseInsensitive = newValue }
        }
    }

    public var description: String {
        return self.sendableAll.description
    }
    
    struct SendableBox: Sendable {
        var all: [SendableRoute]
        var defaultMaxBodySize: ByteCount
        var caseInsensitive: Bool
    }
    
    let sendableBox: NIOLockedValueBox<SendableBox>

    public init() {
        let box = SendableBox(all: [], defaultMaxBodySize: "16kb", caseInsensitive: false)
        self.sendableBox = .init(box)
    }

    @available(*, deprecated, message: "Use SendableRoute instead")
    public func add(_ route: Route) {
        self.sendableBox.withLockedValue {
            $0.all.append(route.sendableRoute)
        }
    }
    
    public func add(_ route: SendableRoute) {
        self.sendableBox.withLockedValue {
            $0.all.append(route)
        }
    }
}

extension Application: RoutesBuilder {
    @available(*, deprecated, message: "Use `sendableAll` instead")
    public func add(_ route: Route) {
        self.routes.add(route)
    }
    
    public func add(_ route: SendableRoute) {
        self.routes.add(route)
    }
}
