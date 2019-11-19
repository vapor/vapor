import NIO

public protocol Provider: class {
    var application: Application { get }
    init(_ application: Application)
    func willBoot() throws
    func didBoot() throws
    func shutdown()
}

extension Provider {
    public func lazy<T>(
        get storage: ReferenceWritableKeyPath<Self, T?>,
        as default: @autoclosure () -> T
    ) -> T {
        self.lazy(get: storage, as: `default`)
    }
    
    public func lazy<T>(
        get storage: ReferenceWritableKeyPath<Self, T?>,
        as default: () -> T
    ) -> T {
        if let existing = self[keyPath: storage] {
            // fast path
            return existing
        } else {
            // slow path
            #warning("synchronize access")
            if let existing = self[keyPath: storage] {
                return existing
            } else {
                let new = `default`()
                self[keyPath: storage] = new
                return new
            }
        }
    }
    
    public func lazy<T>(
        set storage: ReferenceWritableKeyPath<Self, T?>,
        to value: T,
        shutdown: (T) -> () = { _ in }
    ) {
        #warning("synchronize access")
        if let existing = self[keyPath: storage] {
            shutdown(existing)
        }
        self[keyPath: storage] = value
    }
}

extension Provider {
    public func willBoot() throws { }
    public func didBoot() throws { }
    public func shutdown() { }
}


public final class Providers {
    private var lookup: [ObjectIdentifier: Provider]
    private var all: [Provider]
    private var didShutdown: Bool
    
    public func clear() {
        self.lookup = [:]
        self.all = []
    }
    
    init() {
        self.lookup = [:]
        self.all = []
        self.didShutdown = false
    }
    
    func add<T>(_ provider: T)
        where T: Provider
    {
        self.lookup[ObjectIdentifier(T.self)] = provider
    }
    
    public func require<T>(
        _ type: T.Type,
        file: StaticString = #file,
        line: UInt = #line
    ) -> T
        where T: Provider
    {
        guard let provider = self.get(T.self) else {
            fatalError("No service provider \(T.self) registered. Consider registering with app.use(\(T.self).self)", file: file, line: line)
        }
        return provider
    }
    
    public func get<T>(_ type: T.Type) -> T?
        where T: Provider
    {
        self.lookup[ObjectIdentifier(T.self)] as? T
    }
    
    func boot() throws {
        try self.all.forEach { try $0.willBoot() }
        try self.all.forEach { try $0.didBoot() }
    }
    
    func shutdown() {
        self.all.reversed().forEach { $0.shutdown() }
    }
    
    deinit {
        assert(self.didShutdown, "Providers did not shutdown before deinit")
    }
}
