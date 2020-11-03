extension Application {
    public var middleware: Middlewares {
        get {
            if let existing = self.storage[MiddlewaresKey.self] {
                return existing
            } else {
                var new = Middlewares()
                new.use(RouteLoggingMiddleware(logLevel: .info))
                new.use(ErrorMiddleware.default(environment: self.environment))
                self.storage[MiddlewaresKey.self] = new
                return new
            }
        }
        set {
            self.storage[MiddlewaresKey.self] = newValue
        }
    }

    private struct MiddlewaresKey: StorageKey {
        typealias Value = Middlewares
    }
}
