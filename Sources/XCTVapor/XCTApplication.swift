extension Application: XCTApplicationTester {
    public func performTest(request: XCTHTTPRequest) throws -> XCTHTTPResponse {
        try self.testable().performTest(request: request)
    }
}

extension Application {
    public enum Method {
        case inMemory
        case running(port: Int)
        public static var running: Method {
            return .running(port: 8080)
        }
    }

    public func testable(method: Method = .inMemory) throws -> XCTApplicationTester {
        try self.boot()
        switch method {
        case .inMemory:
            return try InMemory(app: self)
        case .running(let port):
            return try Live(app: self, port: port)
        }
    }
    
    private struct Live: XCTApplicationTester {
        let app: Application
        let port: Int

        init(app: Application, port: Int) throws {
            self.app = app
            self.port = port
        }

        func performTest(request test: XCTHTTPRequest) throws -> XCTHTTPResponse {
            let server = try app.server.start(hostname: "localhost", port: self.port)
            defer { server.shutdown() }
            let client = HTTPClient(eventLoopGroupProvider: .createNew)
            defer { try! client.syncShutdown() }
            let path = test.uri.path.hasPrefix("/") ? test.uri.path : "/\(test.uri.path)"
            var request = try HTTPClient.Request(
                url: "http://localhost:\(self.port)\(path)",
                method: test.method,
                headers: test.headers
            )
            request.body = .byteBuffer(test.body)
            let response = try client.execute(request: request).wait()
            return XCTHTTPResponse(
                status: response.status,
                headers: response.headers,
                body: response.body ?? ByteBufferAllocator().buffer(capacity: 0)
            )
        }
    }

    private struct InMemory: XCTApplicationTester {
        let app: Application
        init(app: Application) throws {
            self.app = app
        }

        func performTest(request test: XCTHTTPRequest) throws -> XCTHTTPResponse {
            var headers = test.headers
            headers.replaceOrAdd(
                name: .contentLength,
                value: test.body.readableBytes.description
            )
            let path = test.uri.path.hasPrefix("/") ? test.uri.path : "/" + test.uri.path
            let request = Request(
                application: app,
                method: test.method,
                url: .init(string: path),
                headers: headers,
                collectedBody: test.body,
                remoteAddress: nil,
                on: self.app.eventLoopGroup.next()
            )
            let res = try self.app.responder.respond(to: request).wait()
            return XCTHTTPResponse(
                status: res.status,
                headers: res.headers,
                body: res.body.buffer ?? ByteBufferAllocator().buffer(capacity: 0)
            )
        }
    }
}

public protocol XCTApplicationTester {
    @discardableResult
    func performTest(
        request: XCTHTTPRequest
    ) throws -> XCTHTTPResponse
}

extension XCTApplicationTester {
    @discardableResult
    public func test(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        file: StaticString = #file,
        line: UInt = #line,
        beforeRequest: (inout XCTHTTPRequest) throws -> () = { _ in },
        afterResponse: (XCTHTTPResponse) throws -> () = { _ in }
    ) throws -> XCTApplicationTester {
        var request = XCTHTTPRequest(
            method: method,
            uri: .init(path: path),
            headers: headers,
            body: ByteBufferAllocator().buffer(capacity: 0)
        )
        try beforeRequest(&request)
        let response = try self.performTest(request: request)
        try afterResponse(response)
        return self
    }
}
