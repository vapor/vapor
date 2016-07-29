import Engine
import Routing

@_exported import TypeSafeRouting

extension Droplet: RouteBuilder {
    public typealias HandlerOutput = HTTPResponder

    public func add(
        host: String,
        method: String,
        path: [String],
        handler: RouteHandler<HandlerOutput>
    ) {
        router.add(host: host, method: method, path: path, handler: handler)
    }
}


extension RouteBuilder where Value == HTTPResponder {
    public func add(
        _ method: HTTPMethod,
        _ path: String,
        _ value: Value
    ) {
        var p: [String] = ["*", method.description]
        p += path.components
        add(path: p, handler: .static(value))
    }

    public func group(
        _ path: String,
        filter: (Value) -> (Value) = { $0 },
        closure: (DynamicRouteBuilder<Value, Self>) -> ()
    ) {
        return dynamic(
            host: nil,
            method: nil,
            path: path.components, filter: filter, closure: closure
        )
    }

    public func group(_ middleware: Middleware, closure: (DynamicRouteBuilder<Value, Self>) ->()) {
        group("/", filter: { handler in
            return HTTPRequest.Handler { request in
                return try middleware.respond(to: request, chainingTo: handler)
            }
        }, closure: closure)
    }

    public func group(
        host: String,
        closure: (DynamicRouteBuilder<Value, Self>) -> ()
    ) {
        return dynamic(host: host, method: nil, path: [], closure: closure)
    }
}

extension HTTPRequest: ParametersContainer { }

extension HTTPRequest: Routeable {
    public var routeablePath: [String] {
        var path = [
            uri.host,
            method.description
        ]

        path += uri.path.characters
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0) }

        return path
    }
}

extension String {
    private var components: [String] {
        return characters
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0) }
    }
}

