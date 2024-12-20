import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import XCTest
import Vapor
import NIOPosix

extension Application: XCTApplicationTester {
    public func performTest(request: XCTHTTPRequest) async throws -> XCTHTTPResponse {
         try await self.testable().performTest(request: request)
    }
}

extension Application {
    public enum Method {
        case inMemory
        public static var running: Method {
            return .running(hostname:"localhost", port: 0)
        }
        public static func running(port: Int) -> Self {
            .running(hostname: "localhost", port: port)
        }
        case running(hostname: String, port: Int)
    }

    public func testable(method: Method = .inMemory) async throws -> XCTApplicationTester {
        try await self.boot()
        switch method {
        case .inMemory:
            return try InMemory(app: self)
        case let .running(hostname, port):
            return try Live(app: self, hostname: hostname, port: port)
        }
    }
    
    private struct Live: XCTApplicationTester {
        let app: Application
        let port: Int
        let hostname: String

        init(app: Application, hostname: String = "localhost", port: Int) throws {
            self.app = app
            self.hostname = hostname
            self.port = port
        }
        
        func performTest(request: XCTHTTPRequest) async throws -> XCTHTTPResponse {
            try await app.server.start(address: .hostname(self.hostname, port: self.port))
            let client = HTTPClient(eventLoopGroup: MultiThreadedEventLoopGroup.singleton)
            
            do {
                var path = request.url.path
                path = path.hasPrefix("/") ? path : "/\(path)"
                
                let actualPort: Int
                
                if self.port == 0 {
                    guard let portAllocated = app.http.server.shared.localAddress?.port else {
                        throw Abort(.internalServerError, reason: "Failed to get port from local address")
                    }
                    actualPort = portAllocated
                } else {
                    actualPort = self.port
                }
                
                var url = "http://\(self.hostname):\(actualPort)\(path)"
                if let query = request.url.query {
                    url += "?\(query)"
                }
                var clientRequest = HTTPClientRequest(url: url)
                clientRequest.method = request.method
                clientRequest.headers = request.headers
                clientRequest.body = .bytes(request.body)
                let response = try await client.execute(clientRequest, timeout: .seconds(30))
                // Collect up to 1MB
                let responseBody = try await response.body.collect(upTo: 1024 * 1024)
                try await client.shutdown()
                await app.server.shutdown()
                return XCTHTTPResponse(
                    status: response.status,
                    headers: response.headers,
                    body: responseBody
                )
            } catch {
                try? await client.shutdown()
                await app.server.shutdown()
                throw error
            }
        }
    }

    private struct InMemory: XCTApplicationTester {
        let app: Application
        init(app: Application) throws {
            self.app = app
        }
        
        @discardableResult
        public func performTest(
            request: XCTHTTPRequest
        ) async throws -> XCTHTTPResponse {
            var headers = request.headers
            headers.replaceOrAdd(
                name: .contentLength,
                value: request.body.readableBytes.description
            )
            let request = Request(
                application: app,
                method: request.method,
                url: request.url,
                headers: headers,
                collectedBody: request.body.readableBytes == 0 ? nil : request.body,
                remoteAddress: nil,
                logger: app.logger,
                on: self.app.eventLoopGroup.next()
            )
            let res = try await self.app.responder.respond(to: request)
            return try await XCTHTTPResponse(
                status: res.status,
                headers: res.headers,
                body: res.body.collect(on: request.eventLoop).get() ?? ByteBufferAllocator().buffer(capacity: 0)
            )
        }
    }
}

public protocol XCTApplicationTester: Sendable {
    func performTest(request: XCTHTTPRequest) async throws -> XCTHTTPResponse
}

extension XCTApplicationTester {
    @discardableResult
    public func test(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        file: StaticString = #filePath,
        line: UInt = #line,
        afterResponse: (XCTHTTPResponse) async throws -> ()
    ) async throws -> XCTApplicationTester {
        try await self.test(
            method,
            path,
            headers: headers,
            body: body,
            file: file,
            line: line,
            beforeRequest: { _ in },
            afterResponse: afterResponse
        )
    }

    @discardableResult
    public func test(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        file: StaticString = #filePath,
        line: UInt = #line,
        beforeRequest: (inout XCTHTTPRequest) async throws -> () = { _ in },
        afterResponse: (XCTHTTPResponse) async throws -> () = { _ in }
    ) async throws -> XCTApplicationTester {
        var request = XCTHTTPRequest(
            method: method,
            url: .init(path: path),
            headers: headers,
            body: body ?? ByteBufferAllocator().buffer(capacity: 0)
        )
        try await beforeRequest(&request)
        do {
            let response = try await self.performTest(request: request)
            try await afterResponse(response)
        } catch {
            XCTFail("\(String(reflecting: error))", file: file, line: line)
            throw error
        }
        return self
    }
    
    public func sendRequest(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        file: StaticString = #filePath,
        line: UInt = #line,
        beforeRequest: (inout XCTHTTPRequest) async throws -> () = { _ in }
    ) async throws -> XCTHTTPResponse {
        var request = XCTHTTPRequest(
            method: method,
            url: .init(path: path),
            headers: headers,
            body: body ?? ByteBufferAllocator().buffer(capacity: 0)
        )
        try await beforeRequest(&request)
        do {
            return try await self.performTest(request: request)
        } catch {
            XCTFail("\(String(reflecting: error))", file: file, line: line)
            throw error
        }
    }
}
