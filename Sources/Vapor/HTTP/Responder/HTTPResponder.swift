public protocol HTTPResponder {
    func respond(to request: Request) throws -> Response
}
