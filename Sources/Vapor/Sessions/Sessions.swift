extension Application {
    public var session: SessionDriver {
        self.sessions.driver
    }
    
    public var sessions: Sessions {
        self.providers.require(Sessions.self)
    }
}

public final class Sessions: Provider {
    public let application: Application
    
    let memoryStorage: MemorySessions.Storage
    var factory: (() -> (SessionDriver))?
    
    public var driver: SessionDriver {
        if let factory = self.factory {
            return factory()
        } else {
            return self.memory
        }
    }
    
    public var memory: MemorySessions {
        .init(storage: self.memoryStorage)
    }
    
    public init(_ application: Application) {
        self.memoryStorage = .init()
        self.application = application
    }
    
    public func use(_ factory: @escaping () -> (SessionDriver)) {
        self.factory = factory
    }
}
