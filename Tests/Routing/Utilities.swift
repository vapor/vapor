import HTTP
import Routing

public typealias RequestHandler = (Request) throws -> ResponseRepresentable
extension Request: ParametersContainer {}

extension Router {
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
    var parameters: [String : String]
    init(_ p: [String: String] = [:]) {
        parameters = [:]
    }
}
