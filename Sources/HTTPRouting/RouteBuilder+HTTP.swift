import Routing
import Engine

extension RouteBuilder where Value == HTTPResponder {

    /**
        Adds a route using an HTTP method,
        variadic array of path strings and HTTP closure.
    */
    public func add(
        _ method: HTTPMethod,
        _ path: String ...,
        _ value: (HTTPRequest) throws -> HTTPResponseRepresentable
    ) {
        add(
            path: ["*", method.description] + path,
            value: HTTPRequest.Handler({ request in
                return try value(request).makeResponse(for: request)
            })
        )
    }

    /**
        Creates a RouteGroup given in a closure.
        The route group will prefix all routes
        built inside with the given path.
    */
    public func group(_ path: String ..., closure: (RouteGroup<Value, Self>) -> ()) {
        return group(
            prefix: [nil, nil],
            path: path,
            map: nil,
            closure: closure
        )
    }

    /**
        Creates a RouteGroup given in a closure.
        The route group will filter all routes
        built inside with the given host.
    */
    public func group(host: String, closure: (RouteGroup<Value, Self>) -> ()) {
        return group(
            prefix: [host, nil],
            path: [],
            map: nil,
            closure: closure
        )
    }

    /**
        Creates a RouteGroup given in a closure.
        The route group will prefix all routes
        built inside with the given path.
    */
    public func grouped(_ path: String ...) -> RouteGroup<Value, Self> {
        return grouped(
            prefix: [nil, nil],
            path: path,
            map: nil
        )
    }

    /**
        Creates a RouteGroup given in a closure.
        The route group will filter all routes
        built inside with the given host.
    */
    public func grouped(host: String) -> RouteGroup<Value, Self> {
        return grouped(
            prefix: [host, nil],
            path: [],
            map: nil
        )
    }
}
