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
        self.overrides.append { s in
            s.register(S.self) { _ in
                return instance
            }
        }
        return self
    }
    
    public final class InMemory {
        let container: () throws -> Container
        
        init(container: @escaping () throws -> Container) throws {
            self.container = container
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
        ) throws -> InMemory
            where Body: Encodable
        {
            var body = ByteBufferAllocator().buffer(capacity: 0)
            try body.writeBytes(JSONEncoder().encode(json))
            var headers = HTTPHeaders()
            headers.contentType = .json
            return try self.test(method, path, headers: headers, body: body, closure: closure)
        }
        
        @discardableResult
        public func test(
            _ method: HTTPMethod,
            _ path: String,
            headers: HTTPHeaders = [:],
            body: ByteBuffer? = nil,
            file: StaticString = #file,
            line: UInt = #line,
            closure: (XCTHTTPResponse) throws -> () = { _ in }
        ) throws -> InMemory {
            let container = try self.container()
            defer { container.shutdown() }
            let responder = try container.make(Responder.self)

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
                on: EmbeddedChannel()
            )
            let res = try responder.respond(to: request).wait()
            response = XCTHTTPResponse(status: res.status, headers: res.headers, body: res.body)
            try closure(response)
            return self
        }
    }
    
    public func inMemory() throws -> InMemory {
        return try InMemory(container: self.container)
    }
    
    public final class Live {
        let container: () throws -> Container
        let port: Int

        public struct Running {
            let container: Container
            let server: Server

            public func shutdown() {
                self.server.shutdown()
                self.container.shutdown()
            }
        }
        
        init(container: @escaping () throws -> Container, port: Int) throws {
            self.container = container
            self.port = port
        }

        public func start() throws -> Running {
            let container = try self.container()
            let server = try container.make(Server.self)
            try server.start(hostname: "127.0.0.1", port: port)
            return Running(container: container, server: server)
        }
        
        @discardableResult
        public func test(
            _ method: HTTPMethod,
            _ path: String,
            headers: HTTPHeaders = [:],
            body: ByteBuffer? = nil,
            file: StaticString = #file,
            line: UInt = #line,
            closure: (XCTHTTPResponse) throws -> () = { _ in }
        ) throws -> Live {
            let server = try self.start()
            defer { server.shutdown() }
            
            let client = HTTPClient(eventLoopGroupProvider: .createNew)
            defer { try! client.syncShutdown() }
            var request = try HTTPClient.Request(url: "http://127.0.0.1:\(self.port)\(path)")
            request.headers = headers
            request.method = method
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
    
    public func live(port: Int) throws -> Live {
        return try Live(container: self.container, port: port)
    }
    
    private func container() throws -> Container {
        var s = try self.application.makeServices()
        for override in self.overrides {
            override(&s)
        }
        let c = Container.boot(
            environment: self.application.environment,
            services: s,
            on: self.application.eventLoopGroup.next()
        )
        return try c.wait()
    }
}
