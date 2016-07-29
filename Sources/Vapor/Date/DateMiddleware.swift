import Foundation
import HTTP

public final class DateMiddleware: Middleware {
    public func respond(to request: Request, chainingTo next: HTTPResponder) throws -> HTTPResponse {
        let response = try next.respond(to: request)

        response.headers["Date"] = RFC1123.now()

        return response
    }
}
