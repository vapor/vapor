import Engine
import Branches

extension HTTPRequest: ParameterContainer {}

public final class BranchRouter: Branches.Router<Responder>, Vapor.Router {
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
