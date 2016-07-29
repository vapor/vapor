import Engine
import Routing

@_exported import HTTPRouting
@_exported import TypeSafeRouting

extension Droplet: RouteBuilder {
    public typealias Value = HTTPResponder

    public func add(
        path: [String],
        value: Value
    ) {
        router.add(path: path, value: value)
    }
}

extension RouteBuilder where Value == HTTPResponder {
    public func group(_ middleware: Middleware, closure: (RouteGroup<Value, Self>) ->()) {
        group(prefix: ["*", "*"], path: [], map: { handler in
            return HTTPRequest.Handler { request in
                return try middleware.respond(to: request, chainingTo: handler)
            }
        }, closure: closure)
    }
}
