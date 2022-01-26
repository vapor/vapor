#if compiler(>=5.5) && canImport(_Concurrency)
import NIOCore

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Client {
    public func get(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        return try await self.send(.GET, headers: headers, to: url, beforeSend: beforeSend).get()
    }

    public func post(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        return try await self.send(.POST, headers: headers, to: url, beforeSend: beforeSend).get()
    }

    public func patch(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        return try await self.send(.PATCH, headers: headers, to: url, beforeSend: beforeSend).get()
    }

    public func put(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        return try await self.send(.PUT, headers: headers, to: url, beforeSend: beforeSend).get()
    }

    public func delete(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        return try await self.send(.DELETE, headers: headers, to: url, beforeSend: beforeSend).get()
    }
        
    public func post<T>(_ url: URI, headers: HTTPHeaders = [:], body: T) async throws -> ClientResponse where T: Content {
        return try await self.post(url, headers: headers, beforeSend: { try $0.content.encode(body) })
    }
    
    public func patch<T>(_ url: URI, headers: HTTPHeaders = [:], body: T) async throws -> ClientResponse where T: Content {
        return try await self.patch(url, headers: headers, beforeSend: { try $0.content.encode(body) })
    }
    
    public func put<T>(_ url: URI, headers: HTTPHeaders = [:], body: T) async throws -> ClientResponse where T: Content {
        return try await self.put(url, headers: headers, beforeSend: { try $0.content.encode(body) })
    }

    public func send(
        _ method: HTTPMethod,
        headers: HTTPHeaders = [:],
        to url: URI,
        beforeSend: (inout ClientRequest) throws -> () = { _ in }
    ) async throws -> ClientResponse {
        var request = ClientRequest(method: method, url: url, headers: headers, body: nil)
        try beforeSend(&request)
        return try await self.send(request).get()
    }
    
    public func send(_ request: ClientRequest) async throws -> ClientResponse {
        return try await self.send(request).get()
    }
}

#endif
