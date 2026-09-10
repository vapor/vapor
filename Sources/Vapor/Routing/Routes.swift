/// The routes registered on an ``Application``, along with the settings the router is built from.
package struct RouteStorage: Sendable {
    package var all: [Route] = []

    /// Default value used by `HTTPBodyStreamStrategy.collect` when `maxSize` is `nil`.
    package var defaultMaxBodySize: ByteCount = "16kb"

    /// Routing is case-sensitive by default; set to `true` to match constant path components
    /// without regard to case.
    package var caseInsensitive: Bool = false

    package init() {}

    package mutating func add(_ route: Route) {
        self.all.append(route)
    }
}

/// The routes registered on an ``Application``.
///
/// A view onto the application's route storage rather than a container of its own, so that building
/// routes through it — `app.routes.grouped(...)`, `app.routes.get(...)` — registers them on the
/// application itself. Every change goes through the application's freeze, so routes and routing
/// settings can only be configured before it starts.
public struct Routes: RoutesBuilder, CustomStringConvertible, Sendable {
    let application: Application

    public var all: [Route] {
        get { self.application._routes.value.all }
        nonmutating set { self.application._routes.withValue { $0.all = newValue } }
    }

    /// Default value used by `HTTPBodyStreamStrategy.collect` when `maxSize` is `nil`.
    ///
    /// Applies to every route registered with the default `.collect` strategy. A route can override
    /// it with `.collect(maxSize:)`, or opt out of collection entirely with `.stream`.
    public var defaultMaxBodySize: ByteCount {
        get { self.application._routes.value.defaultMaxBodySize }
        nonmutating set { self.application._routes.withValue { $0.defaultMaxBodySize = newValue } }
    }

    /// Default routing behavior of `DefaultResponder` is case-sensitive; configure to `true` prior to
    /// Application start handle `Constant` `PathComponents` in a case-insensitive manner.
    public var caseInsensitive: Bool {
        get { self.application._routes.value.caseInsensitive }
        nonmutating set { self.application._routes.withValue { $0.caseInsensitive = newValue } }
    }

    public var description: String {
        self.all.description
    }

    public func add(_ route: Route) {
        self.application._routes.withValue { $0.add(route) }
    }
}

extension Application: RoutesBuilder {
    public func add(_ route: Route) {
        self._routes.withValue { $0.add(route) }
    }
}
