extension HTTPClient {
    func delegating(to eventLoop: EventLoop, logger: Logger) -> Client {
        EventLoopHTTPClient(
            http: self,
            eventLoop: eventLoop,
            logger: logger
        )
    }
}

private struct EventLoopHTTPClient: Client {
    let http: HTTPClient
    let eventLoop: EventLoop
    var logger: Logger?

    func send(
        _ client: ClientRequest
    ) -> EventLoopFuture<ClientResponse> {
        let urlString = client.url.string
        guard let url = URL(string: urlString) else {
            self.logger?.debug("\(urlString) is an invalid URL")
            return self.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "\(urlString) is an invalid URL"))
        }
        do {
            let request = try HTTPClient.Request(
                url: url,
                method: client.method,
                headers: client.headers,
                body: client.body.map { .byteBuffer($0) }
            )
            return self.http.execute(
                request: request,
                eventLoop: .delegate(on: self.eventLoop),
                logger: logger
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
        EventLoopHTTPClient(http: self.http, eventLoop: eventLoop, logger: self.logger)
    }

    func logging(to logger: Logger) -> Client {
        return EventLoopHTTPClient(http: self.http, eventLoop: self.eventLoop, logger: logger)
    }
}
