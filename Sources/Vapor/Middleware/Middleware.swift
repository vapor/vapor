import Engine

public protocol Middleware {
    func respond(to request: HTTPRequest, chainingTo next: HTTPResponder) throws -> HTTPResponse
}
