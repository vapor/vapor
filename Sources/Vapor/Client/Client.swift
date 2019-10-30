public protocol Client {
    var eventLoopGroup: EventLoopGroup { get }
    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse>
}

extension Client {
    public func get(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) -> EventLoopFuture<ClientResponse> {
        return self.send(.GET, headers: headers, to: url, beforeSend: beforeSend)
    }

    public func post(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) -> EventLoopFuture<ClientResponse> {
        return self.send(.POST, headers: headers, to: url, beforeSend: beforeSend)
    }

    public func patch(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) -> EventLoopFuture<ClientResponse> {
        return self.send(.PATCH, headers: headers, to: url, beforeSend: beforeSend)
    }

    public func put(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) -> EventLoopFuture<ClientResponse> {
        return self.send(.PUT, headers: headers, to: url, beforeSend: beforeSend)
    }

    public func delete(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) -> EventLoopFuture<ClientResponse> {
        return self.send(.DELETE, headers: headers, to: url, beforeSend: beforeSend)
    }

    public func send(
        _ method: HTTPMethod,
        headers: HTTPHeaders = [:],
        to url: URI,
        beforeSend: (inout ClientRequest) throws -> () = { _ in }
    ) -> EventLoopFuture<ClientResponse> {
        var request = ClientRequest(method: method, url: url, headers: headers, body: nil)
        do {
            try beforeSend(&request)
        } catch {
            return self.eventLoopGroup.next().makeFailedFuture(error)
        }
        return self.send(request)
    }
}
