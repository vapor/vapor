import HTTP
import Routing

extension Droplet: Responder {
    // Responds to requests using the pre-compiled responder
    public func respond(to request: Request) throws -> Response {
        return try responder.respond(to: request)
    }
}
