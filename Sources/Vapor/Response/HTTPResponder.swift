public protocol Responder {
    func respond(
        to req: HTTPRequest,
        using ctx: Context
    ) -> EventLoopFuture<HTTPResponse>
}
