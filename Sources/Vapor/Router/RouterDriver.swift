import Engine

/**
    This protocol defines router objects that can be used to relay
    different paths to the droplet
*/
public protocol Router {
    func route(_ request: HTTPRequest) -> HTTPResponder?
    func register(_ route: Route)
}

import Branches
import Engine

extension HTTPRequest: ParameterContainer {}

public final class AltRouter: Branches.Router<Responder>, Vapor.Router {
    public func register(_ route: Route) {
        register(
            host: route.hostname,
            method: route.method.description,
            path: route.path,
            output: route.responder
        )
    }

    public func route(_ request: HTTPRequest) -> Responder? {
        return route(for: request,
                     host: request.uri.host ?? "*",
                     method: request.method.description,
                     path: request.uri.path ?? "")
    }
}
