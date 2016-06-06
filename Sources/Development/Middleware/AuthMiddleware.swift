import Vapor

class AuthMiddleware: Middleware {
    enum Error: ErrorProtocol {
        case Unauthorized
    }

    func handle(_ handler: Request.Handler) -> Request.Handler {
        return { request in
            guard let session = request.session else {
                throw Error.Unauthorized
            }

            guard session["id"] != nil else {
                throw Error.Unauthorized
            }

            return try handler(request)
        }
    }

}
