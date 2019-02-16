extension Application {
    public func xctest() -> XCTApplication {
        return .init(app: self)
    }
}


public final class XCTApplication {
    public let app: Application
    private var c: Container
    public init(app: Application) {
        self.app = app
        self.c = try! app.makeContainer().wait()
    }
    
    @discardableResult
    public func test(
        _ method: HTTPMethod,
        to string: String,
        file: StaticString = #file,
        line: UInt = #line,
        closure: (XCTHTTPResponse) throws -> ()
    ) throws -> XCTApplication {
        let res = try self.c.make(Responder.self).respond(
            to: .init(method: method, urlString: string),
            using: .init(channel: EmbeddedChannel())
        ).wait()
        try closure(.init(response: res))
        return self
    }
    
    deinit {
        try! self.c.shutdown().wait()
    }
}
