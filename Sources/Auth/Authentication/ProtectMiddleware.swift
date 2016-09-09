import HTTP

public class ProtectMiddleware: Middleware {
    public let error: Error
    public init(error: Error) {
        self.error = error
    }
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        guard try request.subject().authenticated else {
            throw error
        }

        return try next.respond(to: request)
    }
}
