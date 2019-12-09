import NIO

public protocol LifecycleHandler {
    func willBoot(_ application: Application) throws
    func didBoot(_ application: Application) throws
    func shutdown(_ application: Application)
}

extension LifecycleHandler {
    public func willBoot(_ application: Application) throws { }
    public func didBoot(_ application: Application) throws { }
    public func shutdown(_ application: Application) { }
}

//public final class Providers {
////    private var lookup: [ObjectIdentifier: Provider]
//    private var all: [Provider]
//    private var didShutdown: Bool
//    
//    public func clear() {
////        self.lookup = [:]
//        self.all = []
//    }
//    
//    init() {
////        self.lookup = [:]
//        self.all = []
//        self.didShutdown = false
//    }
//    
//    func add(_ provider: Provider) {
//        provider.initialize()
//        self.all.append(provider)
//    }
////
////    public func require<T>(
////        _ type: T.Type,
////        file: StaticString = #file,
////        line: UInt = #line
////    ) -> T
////        where T: Provider
////    {
////        guard let provider = self.get(T.self) else {
////            fatalError("No service provider \(T.self) registered. Consider registering with app.use(\(T.self).self)", file: file, line: line)
////        }
////        return provider
////    }
////
////    public func get<T>(_ type: T.Type) -> T?
////        where T: Provider
////    {
////        self.lookup[ObjectIdentifier(T.self)] as? T
////    }
//    
//    func boot() throws {
//        try self.all.forEach { try $0.willBoot() }
//        try self.all.forEach { try $0.didBoot() }
//    }
//    
//    func shutdown() {
//        self.didShutdown = true
//        self.all.reversed().forEach { $0.shutdown() }
//        self.clear()
//    }
//    
//    deinit {
//        assert(self.didShutdown, "Providers did not shutdown before deinit")
//    }
//}
