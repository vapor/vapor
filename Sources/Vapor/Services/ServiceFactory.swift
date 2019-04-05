struct ServiceFactory<T> {
    /// Accepts a `Container`, returning an initialized service.
    let closure: (Container) throws -> T
    
    let isSingleton: Bool
    
    init(isSingleton: Bool, _ closure: @escaping (Container) throws -> T) {
        self.isSingleton = isSingleton
        self.closure = closure
    }
    
    /// See `ServiceFactory`.
    func serviceMake(for worker: Container) throws -> T {
        return try closure(worker)
    }
}
