final class ServerDelegate: HTTPServerDelegate {
    private let responderCache: ThreadSpecificVariable<ThreadResponder>
    let application: Application
    var containers: [Container]
    
    init(application: Application) {
        self.application = application
        self.responderCache = .init()
        self.containers = []
    }
    
    func respond(to req: HTTPRequest, on channel: Channel) -> EventLoopFuture<HTTPResponse> {
        let ctx = Context(channel: channel)
        if let responder = responderCache.currentValue?.responder {
            return responder.respond(to: req, using: ctx)
        } else {
            return self.application.makeContainer(on: channel.eventLoop).flatMapThrowing { container -> Responder in
                self.containers.append(container)
                let responder = try container.make(Responder.self)
                self.responderCache.currentValue = ThreadResponder(responder: responder)
                return responder
            }.flatMap { responder in
                return responder.respond(to: req, using: ctx)
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
