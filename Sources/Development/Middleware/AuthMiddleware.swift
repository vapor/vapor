import Vapor

class AuthMiddleware: Middleware {
    enum Error: ErrorProtocol {
        case Unauthorized
    }

    func respond(to request: Request, closure: (Request) throws -> Response) throws -> Response {
        guard let session = request.session else {
            throw Error.Unauthorized
        }

        guard session["id"] != nil else {
            throw Error.Unauthorized
        }

        return try closure(request)
    }

}
