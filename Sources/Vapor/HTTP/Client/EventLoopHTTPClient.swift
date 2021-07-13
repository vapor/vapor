import Baggage

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
        _ client: ClientRequest,
        context: LoggingContext
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
                eventLoop: .delegate(on: self.eventLoop),
                context: context
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
