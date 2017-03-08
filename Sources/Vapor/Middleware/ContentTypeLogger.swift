import HTTP

public final class ContentTypeLogger: Middleware {
    public let log: (String) -> Void
    public init(_ log: @escaping (String) -> Void) {
        self.log = log
    }

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        let response = try next.respond(to: request)
        if response.headers["Content-Type"] == nil && response.status != .notModified {
            log("Response had no 'Content-Type' header.")
        }
        return response
    }
}
