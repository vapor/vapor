struct ServerDelegate: HTTPServerDelegate {
    private let responderCache: ThreadSpecificVariable<ThreadResponder>
    let application: Application
    
    init(application: Application) {
        self.application = application
        self.responderCache = .init()
    }
    
    func respond(to http: HTTPRequest, on channel: Channel) -> EventLoopFuture<HTTPResponse> {
        let req = RequestContext(http: http, channel: channel)
        if let responder = responderCache.currentValue?.responder {
            return responder.respond(to: req)
        } else {
            return self.application.makeContainer(on: channel.eventLoop).thenThrowing { container -> Responder in
                let responder = try container.make(Responder.self)
                self.responderCache.currentValue = ThreadResponder(responder: responder)
                return responder
            }.then { responder in
                return responder.respond(to: req)
            }
        }
        
    }
}

private final class ThreadResponder {
    var responder: Responder
    init(responder: Responder) {
        self.responder = responder
    }
}
