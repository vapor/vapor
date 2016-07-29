import Engine
import Routing

extension HTTPRequest: ParametersContainer { }

extension RouteBuilder where Value == HTTPResponder {
    // MARK: Add

    public func add(
        _ method: HTTPMethod,
        _ path: String,
        _ value: Value
    ) {
        add(
            path: ["*", method.description] + path.pathComponents,
            value: value
        )
    }

    public func add(
        _ method: HTTPMethod,
        _ path: [String],
        _ value: Value
    ) {
        add(
            path: ["*", method.description] + path,
            value: value
        )
    }

    // MARK: Group

    public func group(
        _ path: String,
        closure: (RouteGroup<Value, Self>) -> ()
    ) {
        return group(
            prefix: [nil, nil],
            path: path.pathComponents,
            filter: nil,
            closure: closure
        )
    }

    public func group(
        _ path: String ...,
        closure: (RouteGroup<Value, Self>) -> ()
    ) {
        return group(
            prefix: [nil, nil],
            path: path,
            filter: nil,
            closure: closure
        )
    }

    public func group(
        host: String,
        closure: (RouteGroup<Value, Self>) -> ()
    ) {
        return group(
            prefix: [host, nil],
            path: [],
            filter: nil,
            closure: closure
        )
    }

    // MARK: Grouped

    public func grouped(
        _ path: String
        ) -> RouteGroup<Value, Self> {
        return grouped(
            prefix: [nil, nil],
            path: path.pathComponents,
            filter: nil
        )
    }
}


