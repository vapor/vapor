final class ServerResponder: Responder {
    weak var application: Application?
    let eventLoop: EventLoop
    
    private let responderCache: ThreadSpecificVariable<ThreadResponder>
    private var containers: [Container]
    private var didShutdown: Bool
    
    init(application: Application, on eventLoop: EventLoop) {
        self.application = application
        self.responderCache = .init()
        self.containers = []
        self.eventLoop = eventLoop
        self.didShutdown = false
    }
    
    func respond(to request: Request) -> EventLoopFuture<Response> {
        guard let application = self.application else {
            fatalError("Application deinitialized")
        }
        if let responder = self.responderCache.currentValue?.responder {
            return responder.respond(to: request)
        } else {
            return application.makeContainer(on: request.eventLoop).flatMapThrowing { container -> Responder in
                self.containers.append(container)
                let responder = try container.make(Responder.self)
                self.responderCache.currentValue = ThreadResponder(responder: responder)
                return responder
            }.flatMap { responder in
                return responder.respond(to: request)
            }
        }
    }
    
    func shutdown() -> EventLoopFuture<Void> {
        self.didShutdown = true
        return .andAllSucceed(
            self.containers.map { $0.shutdown() },
            on: self.eventLoop
        )
    }
    
    deinit {
        assert(self.didShutdown, "ServerDelegate did not shutdown before deinitializing")
    }
}

private final class ThreadResponder {
    var responder: Responder
    init(responder: Responder) {
        self.responder = responder
    }
}
