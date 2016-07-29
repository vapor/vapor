import Engine
import Routing

@_exported import TypeSafeRouting

extension Droplet: RouteBuilder {
    public typealias Value = HTTPResponder

    public func add(
        host: String?,
        method: String?,
        path: [String],
        value: Value
    ) {
        router.add(host: host, method: method, path: path, value: value)
    }
}


extension RouteBuilder where Value == HTTPResponder {
    public func add(
        _ method: HTTPMethod,
        _ path: String,
        _ value: Value
    ) {
        add(
            host: nil,
            method: method.description,
            path: path.pathComponents,
            value: value
        )
    }

    public func group(
        _ path: String,
        closure: (GroupRouteBuilder<Value, Self>) -> ()
    ) {
        return group(
            host: nil,
            method: nil,
            path: path.pathComponents,
            filter: nil,
            closure: closure
        )
    }

    public func grouped(
        _ path: String
    ) -> GroupRouteBuilder<Value, Self> {
        return grouped(
            host: nil,
            method: nil,
            path: path.pathComponents,
            filter: nil
        )
    }

    public func group(_ middleware: Middleware, closure: (GroupRouteBuilder<Value, Self>) ->()) {
        group(host: nil, method: nil, path: [], filter: { handler in
            return HTTPRequest.Handler { request in
                return try middleware.respond(to: request, chainingTo: handler)
            }
        }, closure: closure)
    }

    public func group(
        host: String,
        closure: (GroupRouteBuilder<Value, Self>) -> ()
    ) {
        return group(host: host, method: nil, path: [], filter: nil, closure: closure)
    }
}

extension HTTPRequest: ParametersContainer { }

extension HTTPRequest {
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
