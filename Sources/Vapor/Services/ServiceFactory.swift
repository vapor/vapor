struct ServiceFactory<T> {
    enum Cache {
        case application
        case container
        case none
    }
    
    let cache: Cache
    let boot: (Container) throws -> T
    let shutdown: (T) throws -> ()
    
    init(
        cache: Cache,
        boot: @escaping (Container) throws -> T,
        shutdown: @escaping (T) throws -> ()
    ) {
        self.cache = cache
        self.boot = boot
        self.shutdown = shutdown
    }
}
