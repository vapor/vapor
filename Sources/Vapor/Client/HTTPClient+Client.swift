extension HTTPClient {
    internal func send(
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
