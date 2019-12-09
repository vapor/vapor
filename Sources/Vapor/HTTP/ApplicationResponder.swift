public struct ApplicationResponder: Responder {
    private let router: Router
    
    init(_ router: Router) {
        self.router = router
    }
    
    public func respond(to request: Request) -> EventLoopFuture<Response> {
        return router.getRoute(for: request).responder.respond(to: request)
    }
}
