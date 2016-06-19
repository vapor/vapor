import Vapor

class AuthMiddleware: Middleware {
    enum Error: ErrorProtocol {
        case Unauthorized
    }

    func respond(to request: HTTP.Request, chainingTo chain: HTTPResponder) throws -> HTTP.Response {
        guard let session = request.session else {
            throw Error.Unauthorized
        }

        guard session["id"] != nil else {
            throw Error.Unauthorized
        }

        return try chain.respond(to: request)
    }

}
