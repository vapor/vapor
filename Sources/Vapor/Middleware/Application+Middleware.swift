extension Application {
    public var middleware: Middlewares {
        get async {
            if let existing = self.storage[MiddlewaresKey.self] {
                return existing
            } else {
                var new = Middlewares()
                new.use(RouteLoggingMiddleware(logLevel: .info))
                new.use(ErrorMiddleware.default(environment: self.environment))
                await self.storage.set(MiddlewaresKey.self, to: new)
                return new
            }
        }
    }
    
    func updateMiddleware(with middleware: Middlewares) async {
        await self.storage.set(MiddlewaresKey.self, to: middleware)
    }

    private struct MiddlewaresKey: StorageKey {
        typealias Value = Middlewares
    }
}
