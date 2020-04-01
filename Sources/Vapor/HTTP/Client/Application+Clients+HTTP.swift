extension Application.Clients.Provider {
    public static var http: Self {
        .init {
            $0.clients.use {
                DelegatingHTTPClient(
                    eventLoop: $0.eventLoopGroup.next(),
                    http: $0.http.client.current
                )
            }
        }
    }
}

private struct DelegatingHTTPClient: Client {
    let eventLoop: EventLoop
    let http: HTTPClient

    func send(
        _ client: ClientRequest
    ) -> EventLoopFuture<ClientResponse> {
        do {
            let request = try HTTPClient.Request(
                url: URL(string: client.url.string)!,
                method: client.method,
                headers: client.headers,
                body: client.body.map { .byteBuffer($0) }
            )
            return self.http.execute(
                request: request,
                eventLoop: .delegate(on: self.eventLoop)
            ).map { response in
                let client = ClientResponse(
                    status: response.status,
                    headers: response.headers,
                    body: response.body
                )
                return client
            }
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
    }

    func delegating(to eventLoop: EventLoop) -> Client {
        DelegatingHTTPClient(eventLoop: eventLoop, http: self.http)
    }
}
