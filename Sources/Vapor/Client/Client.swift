import NIOCore
import Logging
import NIOHTTP1
import HTTPTypes

public protocol Client: Sendable {
    var byteBufferAllocator: ByteBufferAllocator { get }
    var contentConfiguration: ContentConfiguration { get }
    func logging(to logger: Logger) -> Client
    func allocating(to byteBufferAllocator: ByteBufferAllocator) -> Client
    func send(_ request: ClientRequest) async throws -> ClientResponse
}

extension Client {
    public func get(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        try await self.send(.get, headers: headers, to: url, beforeSend: beforeSend)
    }

    public func post(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        try await self.send(.post, headers: headers, to: url, beforeSend: beforeSend)
    }

    public func patch(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        try await self.send(.patch, headers: headers, to: url, beforeSend: beforeSend)
    }

    public func put(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        try await self.send(.put, headers: headers, to: url, beforeSend: beforeSend)
    }

    public func delete(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        try await self.send(.delete, headers: headers, to: url, beforeSend: beforeSend)
    }
    
    public func post<T>(_ url: URI, headers: HTTPHeaders = [:], content: T) async throws -> ClientResponse where T: Content {
        try await self.post(url, headers: headers, beforeSend: { try $0.content.encode(content) })
    }

    public func patch<T>(_ url: URI, headers: HTTPHeaders = [:], content: T) async throws -> ClientResponse where T: Content {
        try await self.patch(url, headers: headers, beforeSend: { try $0.content.encode(content) })
    }

    public func put<T>(_ url: URI, headers: HTTPHeaders = [:], content: T) async throws -> ClientResponse where T: Content {
        try await self.put(url, headers: headers, beforeSend: { try $0.content.encode(content) })
    }

    public func send(
        _ method: HTTPRequest.Method,
        headers: HTTPHeaders = [:],
        to url: URI,
        beforeSend: (inout ClientRequest) throws -> () = { _ in }
    ) async throws -> ClientResponse {
        var request = ClientRequest(method: method, url: url, headers: headers, body: nil, byteBufferAllocator: self.byteBufferAllocator, contentConfiguration: self.contentConfiguration)
        try beforeSend(&request)
        return try await self.send(request)
    }
}
