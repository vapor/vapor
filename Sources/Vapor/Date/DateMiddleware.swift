import Foundation
import HTTP
import Cookies

public final class DateMiddleware: Middleware {
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        let response = try next.respond(to: request)

        response.headers["Date"] = Date().rfc1123

        return response
    }
}
