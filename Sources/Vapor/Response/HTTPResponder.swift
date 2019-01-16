public protocol HTTPResponder {
    func respond(to req: HTTPRequestContext) -> EventLoopFuture<HTTPResponse>
}
