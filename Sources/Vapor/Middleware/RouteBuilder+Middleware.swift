import Engine
import Routing
import TypeSafeRouting

extension RouteBuilder where Value == HTTPResponder {
    public func group(_ middleware: Middleware, closure: (Routing.Router<Value>) ->()) {
        group("/", filter: { handler in
            return HTTPRequest.Handler { request in
                return try middleware.respond(to: request, chainingTo: handler)
            }
        }, closure: closure)
    }
}
