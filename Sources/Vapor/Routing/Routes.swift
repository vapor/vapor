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
        return self.all.description
    }
    
    struct SendableBox: Sendable {
        var all: [Route]
        var defaultMaxBodySize: ByteCount
        var caseInsensitive: Bool
    }
    
    let sendableBox: NIOLockedValueBox<SendableBox>

    public init() {
        let box = SendableBox(all: [], defaultMaxBodySize: "16kb", caseInsensitive: false)
        self.sendableBox = .init(box)
    }

    public func add(_ route: Route) {
        self.sendableBox.withLockedValue {
            $0.all.append(route)
        }
    }
}

extension Application: RoutesBuilder {
    public func add(_ route: Route) async {
        await self.routes.add(route)
    }
}
