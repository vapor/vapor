extension HTTPClient: Client {
    public func send(_ client: ClientRequest) -> EventLoopFuture<ClientResponse> {
        #warning("TODO: return elfuture error")
        let request = try! Request(
            url: client.url,
            version: .init(major: 1, minor: 1),
            method: client.method,
            headers: client.headers, body: client.body.flatMap { .byteBuffer($0) }
        )
        return self.execute(request: request).map { response in
            let client = ClientResponse(
                status: response.status,
                headers: response.headers,
                body: response.body
            )
            return client
        }
    }
 }
