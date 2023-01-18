public protocol Client {
    var eventLoop: EventLoop { get }
    var byteBufferAllocator: ByteBufferAllocator { get }
    func delegating(to eventLoop: EventLoop) -> Client
    func logging(to logger: Logger) -> Client
    func allocating(to byteBufferAllocator: ByteBufferAllocator) -> Client
    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse>
}

extension Client {
    public func logging(to logger: Logger) -> Client {
        return self
    }

    public func allocating(to byteBufferAllocator: ByteBufferAllocator) -> Client {
        return self
    }

    public var byteBufferAllocator: ByteBufferAllocator {
        return ByteBufferAllocator()
    }
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
    
    public func post<T>(_ url: URI, headers: HTTPHeaders = [:], content: T) -> EventLoopFuture<ClientResponse> where T: Content {
        return self.post(url, headers: headers, beforeSend: { try $0.content.encode(content) })
    }

    public func patch<T>(_ url: URI, headers: HTTPHeaders = [:], content: T) -> EventLoopFuture<ClientResponse> where T: Content {
        return self.patch(url, headers: headers, beforeSend: { try $0.content.encode(content) })
    }

    public func put<T>(_ url: URI, headers: HTTPHeaders = [:], content: T) -> EventLoopFuture<ClientResponse> where T: Content {
        return self.put(url, headers: headers, beforeSend: { try $0.content.encode(content) })
    }

    public func send(
        _ method: HTTPMethod,
        headers: HTTPHeaders = [:],
        to url: URI,
        beforeSend: (inout ClientRequest) throws -> () = { _ in }
    ) -> EventLoopFuture<ClientResponse> {
        var request = ClientRequest(method: method, url: url, headers: headers, body: nil, byteBufferAllocator: self.byteBufferAllocator)
        do {
            try beforeSend(&request)
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
        return self.send(request)
    }
}
