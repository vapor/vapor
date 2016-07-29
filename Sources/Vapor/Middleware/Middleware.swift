import HTTP

public protocol Middleware {
    func respond(to request: Request, chainingTo next: HTTPResponder) throws -> HTTPResponse
}
