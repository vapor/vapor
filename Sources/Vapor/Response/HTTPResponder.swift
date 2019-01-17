public protocol Responder {
    func respond(to req: RequestContext) -> EventLoopFuture<HTTPResponse>
}
