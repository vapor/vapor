import Vapor

class AuthMiddleware: Middleware {
    enum Error: Swift.Error {
        case Unauthorized
    }

    func respond(to request: Request, chainingTo chain: Responder) throws -> Response {
        guard let session = request.session else {
            throw Error.Unauthorized
        }

        guard session["id"] != nil else {
            throw Error.Unauthorized
        }

        return try chain.respond(to: request)
    }
}
