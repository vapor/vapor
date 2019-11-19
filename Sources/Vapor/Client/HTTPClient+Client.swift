struct ApplicationClient: Client {
    let http: HTTPClient

    var eventLoopGroup: EventLoopGroup {
        return self.http.eventLoopGroup
    }

    func `for`(_ request: Request) -> Client {
        RequestClient(http: self.http, req: request)
    }
    
    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        return self.http.send(request, eventLoop: .indifferent)
    }
}

extension Request {
    public var client: Client {
        return self.application.client.for(self)
    }
}

struct RequestClient: Client {
    let http: HTTPClient
    let req: Request

    var eventLoopGroup: EventLoopGroup {
        return self.http.eventLoopGroup
    }
    
    func `for`(_ request: Request) -> Client {
        RequestClient(http: self.http, req: request)
    }

    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        return self.http.send(request, eventLoop: .delegate(on: self.req.eventLoop))
    }
}

private extension HTTPClient {
    func send(
        _ client: ClientRequest,
        eventLoop: HTTPClient.EventLoopPreference
    ) -> EventLoopFuture<ClientResponse> {
        do {
            let request = try HTTPClient.Request(
                url: URL(string: client.url.string)!,
                method: client.method,
                headers: client.headers,
                body: client.body.map { .byteBuffer($0) }
            )
            return self.execute(request: request, eventLoop: eventLoop).map { response in
                let client = ClientResponse(
                    status: response.status,
                    headers: response.headers,
                    body: response.body
                )
                return client
            }
        } catch {
            return self.eventLoopGroup.next().makeFailedFuture(error)
        }
    }
}
