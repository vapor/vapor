extension Request {
    public var client: Client {
        self.application.clients.client.for(self)
    }
}

//struct RequestClient: Client {
//    let http: HTTPClient
//    let req: Request
//
//    var eventLoopGroup: EventLoopGroup {
//        return self.req.eventLoop
//    }
//
//    func `for`(_ request: Request) -> Client {
//        RequestClient(http: self.http, req: request)
//    }
//
//    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
//        return self.http.send(request, eventLoop: .delegate(on: self.req.eventLoop))
//    }
//}
