import Foundation

/**
 A `Middleware` for session management. It is responsible
 for reading a `Request`s cookies to identify an existing
 session or creating a new one.

 An instance of this middleware is added when an `Application` is created.
 */
class SessionMiddleware: Middleware {
    private let sessionDriver: SessionDriver

    init(sessionDriver: SessionDriver) {
        self.sessionDriver = sessionDriver
    }

    func handle(handler: Request.Handler) -> Request.Handler {
        return { request in

            let sessionIdentifier = request.cookies["vapor-session"] ?? self.createSessionIdentifier()
            request.session.sessionIdentifier = sessionIdentifier

            let response = try handler(request: request)

            response.cookies["vapor-session"] = sessionIdentifier

            return response
        }
    }

    private func createSessionIdentifier() -> String {
        var identifier = String(NSDate().timeIntervalSinceNow)
        identifier += "v@p0r"
        identifier += String(Int.random(min: 0, max: 9999))
        identifier += "s3sS10n"
        identifier += String(Int.random(min: 0, max: 9999))
        identifier += "k3y"
        identifier += String(Int.random(min: 0, max: 9999))
        return Hash.make(identifier)
    }

}
