extension Application {
    public var routes: Routes {
        if let existing = self.storage[RoutesKey.self] {
            return existing
        } else {
            let new = Routes()
            self.storage[RoutesKey.self] = new
            return new
        }
    }

    private struct RoutesKey: StorageKey {
        typealias Value = Routes
    }
}

public final class Routes: RoutesBuilder, CustomStringConvertible {
    public var all: [Route]

    public var defaultMaxBodySize: ByteCount

    public var description: String {
        return self.all.description
    }

    public init() {
        self.all = []
        self.defaultMaxBodySize = "16kb"
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
