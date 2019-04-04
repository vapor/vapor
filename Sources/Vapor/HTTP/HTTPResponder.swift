public protocol Responder {
    func respond(to request: Request) -> EventLoopFuture<Response>
}
