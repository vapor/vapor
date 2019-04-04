extension Application {
    public func xctest() -> XCTApplication {
        return .init(app: self)
    }
}


public final class XCTApplication {
    public let app: Application
    private var serviceOverrides: [(inout Services) -> ()]
    
    private var _container: Container?
    public init(app: Application) {
        self.app = app
        self.serviceOverrides = []
    }
    
    @discardableResult
    public func override<T>(service: T.Type, with value: T) -> XCTApplication {
        return self.override(service: T.self) { _ in value }
    }
    
    public func override<T>(service: T.Type, with factory: @escaping (Container) throws -> T) -> XCTApplication {
        self.serviceOverrides.append({ services in
            services.register(T.self, factory)
        })
        return self
    }
    
    @discardableResult
    public func test(
        _ method: HTTPMethod,
        to string: String,
        file: StaticString = #file,
        line: UInt = #line,
        closure: (XCTHTTPResponse) throws -> () = { _ in }
    ) throws -> XCTApplication {
        let res = try self.container().make(Responder.self).respond(
            to: .init(http: .init(method: method, urlString: string), channel: EmbeddedChannel())
        ).wait()
        try closure(.init(response: res))
        return self
    }
    
    private func container() throws -> Container {
        if let existing = self._container {
            return existing
        } else {
            var services = try self.app._makeServices()
            for override in self.serviceOverrides {
                override(&services)
            }
            let new = try Container.boot(
                env: app.env,
                services: services,
                on: app.eventLoopGroup.next()
                ).wait()
            self._container = new
            return new
        }
    }
    
    deinit {
        try! self._container?.shutdown().wait()
    }
}
