import Vapor

class AuthMiddleware: Middleware {
    enum Error: ErrorProtocol {
        case Unauthorized
    }

    static func handle(handler: Request.Handler, for application: Application) -> Request.Handler {
        return { request in
            guard let session = request.session else {
                throw Error.Unauthorized
            }

            guard session["id"] != nil else {
                throw Error.Unauthorized
            }

            return try handler(request: request)
        }
    }

}
