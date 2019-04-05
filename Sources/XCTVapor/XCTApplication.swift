extension Application {
    public func testable() -> XCTApplication {
        return .init(application: self)
    }
}

public final class XCTApplication {
    let application: Application
    
    init(application: Application) {
        self.application = application
    }
    
    public final class InMemory {
        let container: Container
        let responder: Responder
        
        init(container: Container) throws {
            self.container = container
            self.responder = try self.container.make(Responder.self)
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
            let response: XCTHTTPResponse
            let request = Request(
                method: method,
                url: URL(string: path)!,
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
            file: StaticString = #file,
            line: UInt = #line,
            closure: (XCTHTTPResponse) throws -> () = { _ in }
        ) throws -> Live {
            let client = URLSession(configuration: .default)
            let promise = self.container.eventLoop.makePromise(of: XCTHTTPResponse.self)
            let url = URL(string: "http://127.0.0.1:\(self.port)\(path)")!
            print("get \(url)")
            client.dataTask(with: URLRequest(url: url)) { data, response, error in
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
                client.invalidateAndCancel()
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
        return try self.application.makeContainer().wait()
    }
}
