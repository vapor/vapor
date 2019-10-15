extension Application {
    public func testable() -> XCTApplication {
        return .init(application: self)
    }
}

public final class XCTApplication {
    let application: Application
    var overrides: [(inout Services) -> ()]
    
    init(application: Application) {
        self.application = application
        self.overrides = []
    }
    
    public func override<S>(service: S.Type, with instance: S) -> Self {
        self.application.services.register(S.self) { _ in
            return instance
        }
        return self
    }

    public enum Method {
        case inMemory
        case running(port: Int)
        public static var running: Method {
            return .running(port: 8080)
        }
    }

    public func start(method: Method = .inMemory) throws -> XCTApplicationTester {
        let container = try self.application.makeContainer()
        switch method {
        case .inMemory:
            return try InMemory(container: container)
        case .running(let port):
            return try Live(container: container, port: port)
        }
    }
    
    private struct Live: XCTApplicationTester {
        let container: Container
        let server: Server
        let port: Int

        init(container: Container, port: Int) throws {
            self.container = container
            self.port = port
            self.server = try container.make(Server.self)
            try server.start(hostname: "localhost", port: port)
        }

        public func shutdown() {
            self.server.shutdown()
            self.container.shutdown()
        }
        
        @discardableResult
        public func performTest(
            method: HTTPMethod,
            path: String,
            headers: HTTPHeaders,
            body: ByteBuffer?,
            file: StaticString,
            line: UInt,
            closure: (XCTHTTPResponse) throws -> ()
        ) throws -> XCTApplicationTester {
            let client = HTTPClient(eventLoopGroupProvider: .createNew)
            defer { try! client.syncShutdown() }
            var request = try HTTPClient.Request(
                url: "http://localhost:\(self.port)\(path)",
                method: method,
                headers: headers
            )
            if let body = body {
                request.body = .byteBuffer(body)
            }
            let response = try client.execute(request: request).wait()
            try closure(XCTHTTPResponse(
                status: response.status,
                headers: response.headers,
                body: response.body.flatMap { .init(buffer: $0) } ?? .init()
            ))
            return self
        }
    }

    private struct InMemory: XCTApplicationTester {
        let container: Container

        init(container: Container) throws {
            self.container = container
        }

        public func shutdown() {
            self.container.shutdown()
        }

        @discardableResult
        public func performTest(
            method: HTTPMethod,
            path: String,
            headers: HTTPHeaders,
            body: ByteBuffer?,
            file: StaticString,
            line: UInt,
            closure: (XCTHTTPResponse) throws -> ()
        ) throws -> XCTApplicationTester {
            let responder = try self.container.make(Responder.self)
            var headers = headers
            if let body = body {
                headers.replaceOrAdd(name: .contentLength, value: body.readableBytes.description)
            }
            let response: XCTHTTPResponse
            let request = Request(
                method: method,
                url: .init(string: path),
                headers: headers,
                collectedBody: body,
                remoteAddress: nil,
                on: self.container.eventLoop.next()
            )
            let res = try responder.respond(to: request).wait()
            response = XCTHTTPResponse(status: res.status, headers: res.headers, body: res.body)
            try closure(response)
            return self
        }
    }
}

public protocol XCTApplicationTester {
    @discardableResult
    func performTest(
        method: HTTPMethod,
        path: String,
        headers: HTTPHeaders,
        body: ByteBuffer?,
        file: StaticString,
        line: UInt,
        closure: (XCTHTTPResponse) throws -> ()
    ) throws -> XCTApplicationTester

    func shutdown()
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
        closure: (XCTHTTPResponse) throws -> () = { _ in }
    ) throws -> XCTApplicationTester {
        return try self.performTest(
            method: method,
            path: path,
            headers: headers,
            body: body,
            file: file,
            line: line,
            closure: closure
        )
    }

    @discardableResult
    public func test<Body>(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        json: Body,
        file: StaticString = #file,
        line: UInt = #line,
        closure: (XCTHTTPResponse) throws -> () = { _ in }
    ) throws -> XCTApplicationTester
        where Body: Encodable
    {
        var body = ByteBufferAllocator().buffer(capacity: 0)
        try body.writeBytes(JSONEncoder().encode(json))
        var headers = HTTPHeaders()
        headers.contentType = .json
        return try self.test(method, path, headers: headers, body: body, closure: closure)
    }
}
