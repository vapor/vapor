import Foundation

/**
 A `Middleware` for session management. It is responsible
 for reading a `Request`s cookies to identify an existing
 session or creating a new one.

 An instance of this middleware is added when an `Application` is created.
 */
class SessionMiddleware: Middleware {

    init() { }

    func handle(handler: Request.Handler) -> Request.Handler {
        return { request in

            let sessionIdentifier = request.cookies["vapor-session"] ?? Session.driver.createSessionIdentifier()
            request.session.sessionIdentifier = sessionIdentifier

            let response = try handler(request: request)

            response.cookies["vapor-session"] = sessionIdentifier

            return response
        }
    }
}
