struct ServiceFactory<T> {
    let isSingleton: Bool
    let boot: (Container) throws -> T
    let shutdown: (T) throws -> ()
    
    init(
        isSingleton: Bool,
        boot: @escaping (Container) throws -> T,
        shutdown: @escaping (T) throws -> ()
    ) {
        self.isSingleton = isSingleton
        self.boot = boot
        self.shutdown = shutdown
    }
}
