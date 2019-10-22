struct ServiceFactory<T> {
    enum Cache {
        case singleton
        case none
    }
    
    let cache: Cache
    let boot: (Application) throws -> T
    let shutdown: (T) throws -> ()
    
    init(
        cache: Cache,
        boot: @escaping (Application) throws -> T,
        shutdown: @escaping (T) throws -> ()
    ) {
        self.cache = cache
        self.boot = boot
        self.shutdown = shutdown
    }
}

struct RequestServiceFactory<T> {
    let boot: (Request) throws -> T

    init(boot: @escaping (Request) throws -> T) {
        self.boot = boot
    }
}
