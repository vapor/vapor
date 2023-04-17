// All this is configured on app start-up and never concurrently so
// this can all be unchecked
public final class Routes: @unchecked Sendable, RoutesBuilder, CustomStringConvertible {
    public var all: [Route]
    
    /// Default value used by `HTTPBodyStreamStrategy.collect` when `maxSize` is `nil`.
    public var defaultMaxBodySize: ByteCount
    /// Default routing behavior of `DefaultResponder` is case-sensitive; configure to `true` prior to
    /// Application start handle `Constant` `PathComponents` in a case-insensitive manner.
    public var caseInsensitive: Bool

    public var description: String {
        return self.all.description
    }

    public init() {
        self.all = []
        self.defaultMaxBodySize = "16kb"
        self.caseInsensitive = false
    }

    public func add(_ route: Route) {
        self.all.append(route)
    }
}

extension Application: RoutesBuilder {
    public func add(_ route: Route) {
        self.routes.add(route)
    }
}
