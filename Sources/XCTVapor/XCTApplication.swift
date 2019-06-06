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
        let container: Container
        let responder: Responder
        
        init(container: Container) throws {
            self.container = container
            self.responder = try self.container.make(Responder.self)
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
            let res = try self.responder.respond(to: request).wait()
            response = XCTHTTPResponse(status: res.status, headers: res.headers, body: res.body)
            try closure(response)
            return self
        }
        
        deinit {
            self.container.shutdown()
        }
    }
    
    public func inMemory() throws -> InMemory {
        return try InMemory(container: self.container())
    }
    
    public final class Live {
        let container: Container
        let server: Server
        let port: Int
        
        init(container: Container, port: Int) throws {
            self.container = container
            self.port = port
            self.server = try self.container.make(Server.self)
            try self.server.start(hostname: "127.0.0.1", port: port)
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
            let client = URLSession(configuration: .default)
            let promise = self.container.eventLoop.makePromise(of: XCTHTTPResponse.self)
            let url = URL(string: "http://127.0.0.1:\(self.port)\(path)")!
            var request = URLRequest(url: url)
            for (name, value) in headers {
                request.addValue(name, forHTTPHeaderField: value)
            }
            request.httpMethod = method.string
            if var body = body {
                request.httpBody = body.readData(length: body.readableBytes)
            }
            client.dataTask(with: request) { data, response, error in
                if let error = error {
                    promise.fail(error)
                } else if let response = response as? HTTPURLResponse {
                    let xresponse = XCTHTTPResponse(
                        status: .init(statusCode: response.statusCode),
                        headers: .init(foundation: response.allHeaderFields),
                        body: data.flatMap { .init(data: $0) } ?? .empty
                    )
                    promise.succeed(xresponse)
                } else {
                    promise.fail(Abort(.internalServerError))
                }
                #if !os(Linux)
                client.invalidateAndCancel()
                #endif
            }.resume()
            try closure(promise.futureResult.wait())
            return self
        }
        
        deinit {
            self.server.shutdown()
            self.container.shutdown()
        }
    }
    
    public func live(port: Int) throws -> Live {
        return try Live(container: self.container(), port: port)
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
