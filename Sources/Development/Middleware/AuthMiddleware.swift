import Vapor

class AuthMiddleware: Middleware {
    enum Error: ErrorProtocol {
        case Unauthorized
    }

    func respond(to request: HTTPRequest, chainingTo chain: Responder) throws -> HTTPResponse {
        guard let session = request.session else {
            throw Error.Unauthorized
        }

        guard session["id"] != nil else {
            throw Error.Unauthorized
        }

        return try chain.respond(to: request)
    }
}
