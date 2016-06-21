public protocol HTTPResponder: ResponderProtocol {
    func respond(to request: Request) throws -> Response
}
