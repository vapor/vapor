 extension HTTPClient: Client {
    public func send(_ client: ClientRequest) -> EventLoopFuture<ClientResponse> {
        let request = Request(
            method: client.method,
            url: client.url,
            headers: client.headers,
            body: client.body
        )
        return self.send(request).map { response in
            let client = ClientResponse(
                status: response.status,
                headers: response.headers,
                body: response.body
            )
            return client
        }
    }
 }
