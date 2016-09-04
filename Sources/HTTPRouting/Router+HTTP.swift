import Routing
import HTTP

extension Routing.Router {
    /**
        Registers a route using an Request.
        The Request will also be used as the ParametersContainer.
    */
    public func route(_ request: HTTP.Request) -> Output? {
        return route(request, with: request)
    }

    /**
        Registers a route using a Request 
        and a ParamatersContainer.
    */
    public func route(_ request: HTTP.Request, with container: Routing.ParametersContainer) -> Output? {
        return route(
            host: request.uri.host,
            method: request.method,
            path: request.uri.path,
            with: request
        )
    }

    /**
        Queries the Router for a result using a 
        host, method, and path string.
    */
    public func route(
        host: String?,
        method: HTTP.Method,
        path: String,
        with container: Routing.ParametersContainer
    ) -> Output? {
        var host = host
        if host?.isEmpty == true {
            host = nil
        }

        return route(path: [
            host ?? "*",
            method.description,
        ] + path.pathComponents, with: container)
    }
}
