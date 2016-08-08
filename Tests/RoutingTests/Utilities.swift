import HTTP
import Routing
import Node

public typealias RequestHandler = (Request) throws -> ResponseRepresentable

private let parametersKey = "parameters"
extension HTTP.Request: Routing.ParametersContainer {
    public var parameters: Node {
        get {
            let node: Node

            if let existing = storage[parametersKey] as? Node {
                node = existing
            } else {
                node = Node.object([:])
                storage[parametersKey] = node
            }

            return node
        }
        set {
            storage[parametersKey] = newValue
        }
    }
}


extension Routing.Router {
    public func route(_ request: Request) -> Output? {
        let host = request.uri.host.isEmpty ? "*" : request.uri.host
        return route(
            path: [host, request.method.description] + request.uri.path.pathComponents,
            with: request
        )
    }
}

extension String {
    private var pathComponents: [String] {
        return characters
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0) }
    }
}

class BasicContainer: ParametersContainer {
    var parameters: Node
    init() {
        parameters = Node.object([:])
    }
}
