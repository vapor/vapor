import Routing
import HTTP

extension Routing.RouteBuilder where Value == HTTP.Responder {

    /**
        Adds a route using an HTTP method,
        variadic array of path strings and HTTP closure.
    */
    public func add(
        _ method: HTTP.Method,
        _ path: String ...,
        _ value: @escaping (HTTP.Request) throws -> HTTP.ResponseRepresentable
    ) {
        add(
            path: ["*", method.description] + path.splitPaths(),
            value: HTTP.Request.Handler({ request in
                return try value(request).makeResponse()
            })
        )
    }

    /**
        Creates a RouteGroup given in a closure.
        The route group will prefix all routes
        built inside with the given path.
    */
    public func group(_ path: String ..., closure: (Routing.RouteGroup<Value, Self>) -> ()) {
        return group(
            prefix: [nil, nil],
            path: path.splitPaths(),
            map: nil,
            closure: closure
        )
    }

    /**
        Creates a RouteGroup given in a closure.
        The route group will filter all routes
        built inside with the given host.
    */
    public func group(host: String, closure: (Routing.RouteGroup<Value, Self>) -> ()) {
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
    public func grouped(_ path: String ...) -> Routing.RouteGroup<Value, Self> {
        return grouped(
            prefix: [nil, nil],
            path: path.splitPaths(),
            map: nil
        )
    }

    /**
        Creates a RouteGroup given in a closure.
        The route group will filter all routes
        built inside with the given host.
    */
    public func grouped(host: String) -> Routing.RouteGroup<Value, Self> {
        return grouped(
            prefix: [host, nil],
            path: [],
            map: nil
        )
    }
}
