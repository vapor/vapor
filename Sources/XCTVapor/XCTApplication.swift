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

        func performTest(request: XCTHTTPRequest) throws -> XCTHTTPResponse {
            try app.server.start(hostname: "localhost", port: self.port)
            defer { app.server.shutdown() }
            
            let client = HTTPClient(eventLoopGroupProvider: .createNew)
            defer { try! client.syncShutdown() }
            var path = request.url.path
            path = path.hasPrefix("/") ? path : "/\(path)"
            var url = "http://localhost:\(self.port)\(path)"
            if let query = request.url.query {
                url += "?\(query)"
            }
            var clientRequest = try HTTPClient.Request(
                url: url,
                method: request.method,
                headers: request.headers
            )
            clientRequest.body = .byteBuffer(request.body)
            let response = try client.execute(request: clientRequest).wait()
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

        @discardableResult
        public func performTest(
            request: XCTHTTPRequest
        ) throws -> XCTHTTPResponse {
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
                collectedBody: request.body,
                remoteAddress: nil,
                on: self.app.eventLoopGroup.next()
            )
            let res = try self.app.responder.respond(to: request).wait()
            return try XCTHTTPResponse(
                status: res.status,
                headers: res.headers,
                body: res.body.collect(on: request.eventLoop).wait() ?? ByteBufferAllocator().buffer(capacity: 0)
            )
        }
    }
}

public protocol XCTApplicationTester {
    func performTest(request: XCTHTTPRequest) throws -> XCTHTTPResponse
}

extension XCTApplicationTester {
    @discardableResult
    public func test(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        file: StaticString = #file,
        line: UInt = #line,
        beforeRequest: (inout XCTHTTPRequest) throws -> () = { _ in },
        afterResponse: (XCTHTTPResponse) throws -> () = { _ in }
    ) throws -> XCTApplicationTester {
        var request = XCTHTTPRequest(
            method: method,
            url: .init(path: path),
            headers: headers,
            body: body ?? ByteBufferAllocator().buffer(capacity: 0)
        )
        try beforeRequest(&request)
        do {
            let response = try self.performTest(request: request)
            try afterResponse(response)
        } catch {
            XCTFail("\(error)", file: (file), line: line)
            throw error
        }
        return self
    }
}
