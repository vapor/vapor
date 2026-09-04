#warning("This should be internal")
public import NIOCore
public import Testing
public import Vapor
public import HTTPTypes

public protocol TestingApplicationTester: Sendable {
    func performTest(request: TestingHTTPRequest) async throws -> TestingHTTPResponse
}

extension Application.Live: TestingApplicationTester {}
extension Application.InMemory: TestingApplicationTester {}

extension Application: TestingApplicationTester {
    public func testing(method: Method = .inMemory) async throws -> any TestingApplicationTester {
        try await self.boot()
        switch method {
        case .inMemory:
            return try InMemory(app: self)
        case let .running(hostname, port):
            return try Live(app: self, hostname: hostname, port: port)
        }
    }

    public func performTest(request: TestingHTTPRequest) async throws -> TestingHTTPResponse {
        try await self.testing().performTest(request: request)
    }

    public func testing<T>(_ method: Method = .inMemory, _ body: (any TestClient) async throws -> T) async throws -> T {
        try await self.boot()
        switch method {
        case .inMemory:
            return try await inMemoryTesting(body)
        case .running(let hostname, let port):
            fatalError()
        }
    }

    private func inMemoryTesting<T>(_ body: (any TestClient) async throws -> T) async throws -> T {
        let client = InMemoryTestClient(app: self, responder: self.makeResponder())
        return try await body(client)
    }
}

extension TestingApplicationTester {
    public func test(
        _ method: HTTPRequest.Method,
        _ path: String,
        headers: HTTPFields = [:],
        body: ByteBuffer? = nil,
        responseBodyCollection: ResponseBodyCollection = .collect,
        sourceLocation: SourceLocation = #_sourceLocation,
        afterResponse: (TestingHTTPResponse) async throws -> ()
    ) async throws {
        try await self.test(
            method,
            path,
            headers: headers,
            body: body,
            responseBodyCollection: responseBodyCollection,
            sourceLocation: sourceLocation,
            beforeRequest: { _ in },
            afterResponse: afterResponse
        )
    }

    public func test(
        _ method: HTTPRequest.Method,
        _ path: String,
        headers: HTTPFields = [:],
        body: ByteBuffer? = nil,
        responseBodyCollection: ResponseBodyCollection = .collect,
        sourceLocation: SourceLocation = #_sourceLocation,
        beforeRequest: (inout TestingHTTPRequest) async throws -> () = { _ in },
        afterResponse: (TestingHTTPResponse) async throws -> () = { _ in }
    ) async throws {
        var request = TestingHTTPRequest(
            method: method,
            url: .init(path: path),
            headers: headers,
            body: body ?? ByteBufferAllocator().buffer(capacity: 0),
            contentConfiguration: .default(),
            responseBodyCollection: responseBodyCollection
        )
        try await beforeRequest(&request)
        do {
            let response = try await self.performTest(request: request)
            try await afterResponse(response)
        } catch {
            Issue.record("\(String(reflecting: error))", sourceLocation: sourceLocation)
            throw error
        }
    }

    public func sendRequest(
        _ method: HTTPRequest.Method,
        _ path: String,
        hostname: String = "127.0.0.1",
        port: Int? = nil,
        headers: HTTPFields = [:],
        body: ByteBuffer? = nil,
        responseBodyCollection: ResponseBodyCollection = .collect,
        sourceLocation: SourceLocation = #_sourceLocation,
        beforeRequest: (inout TestingHTTPRequest) async throws -> () = { _ in }
    ) async throws -> TestingHTTPResponse {
        var request = TestingHTTPRequest(
            method: method,
            url: .init(scheme: "http", host: hostname, port: port, path: path),
            headers: headers,
            body: body ?? ByteBufferAllocator().buffer(capacity: 0),
            contentConfiguration: .default(),
            responseBodyCollection: responseBodyCollection
        )
        try await beforeRequest(&request)
        do {
            return try await self.performTest(request: request)
        } catch {
            Issue.record("\(String(reflecting: error))", sourceLocation: sourceLocation)
            throw error
        }
    }
}
