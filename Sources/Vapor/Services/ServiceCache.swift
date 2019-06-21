internal struct ServiceCache {
    private var storage: [ServiceID: AnyCachedService]

    init() {
        self.storage = [:]
    }

    func get<S>(service: S.Type) -> CachedService<S>? {
        let id = ServiceID(S.self)
        guard let service = self.storage[id] as? CachedService<S> else {
            return nil
        }
        return service
    }

    mutating func set<S>(service: CachedService<S>) {
        let id = ServiceID(S.self)
        self.storage[id] = service
    }

    mutating func shutdown() {
        self.storage.values.forEach { $0.cleanup() }
        self.storage = [:]
    }
}

internal struct CachedService<T>: AnyCachedService {
    let service: T
    let shutdown: (T) throws -> ()
    func cleanup() {
        do {
            try self.shutdown(self.service)
        } catch {
            Logger(label: "codes.vapor.services")
                .error("Could not shutdown service \(T.self): \(error)")
        }
    }
}

private protocol AnyCachedService {
    func cleanup()
}
