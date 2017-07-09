public struct ServiceType {
    var type: Service.Type
    var isSingleton: Bool
}

public struct ServiceInstance {
    var instance: Any
}

public struct Services {
    var types: [ServiceType]
    var instances: [ServiceInstance]
    var providerTypes: [Provider.Type]
    var providers: [Provider]
    
    public init() {
        self.types = []
        self.instances = []
        self.providerTypes = []
        self.providers = []
    }
}

import Console
import Sessions
import Cache

extension Config {
    public static func `default`() -> Config {
        var config = Config([:])
        
        try! config.set("droplet.client", "engine")
        try! config.set("droplet.middleware", ["error", "file", "date"])
        try! config.set("droplet.commands", ["serve", "routes", "dump-config"])
        
        return config
    }
}

extension Services {
    public static func `default`() -> Services {
        var services = Services()
        services.register(Terminal.self)
        services.register(ConsoleLogger.self)
        
        // cache
        services.register(MemoryCache.self)
        services.register(CacheSessions.self)
        
        // middleware
        services.register(SessionsMiddleware.self)
        services.register(ErrorMiddleware.self)
        services.register(FileMiddleware.self)
        services.register(DateMiddleware.self)
        services.register(CORSMiddleware.self)
        
        // cipher
        services.register(CryptoCipher.self)
        
        // hash
        services.register(CryptoHasher.self)
        services.register(BCryptHasher.self)
        
        // engine
        services.register(ClientFactory<EngineClient>.self)
        services.register(ClientFactory<FoundationClient>.self)
        services.register(ServerFactory<EngineServer>.self)
        
        // commands
        services.register(DumpConfig.self)
        services.register(Serve.self)
        services.register(RouteList.self)
        
        // sessions
        services.register(MemorySessions.self)
        services.register(CacheSessions.self)
        return services
    }
}

extension Services {
    public mutating func register<S: Service>(
        _ type: S.Type = S.self,
        isSingleton: Bool = true
    ) {
        let st = ServiceType(type: type, isSingleton: isSingleton)
        types.append(st)
    }
    
    
    public mutating func instance<S>(_ instance: S) {
        let si = ServiceInstance(instance: instance)
        instances.append(si)
    }
    
    public mutating func provider<P: Provider>(_ p: P.Type) {
        guard !providerTypes.contains(where: { $0 == P.self }) else {
            return
        }
        
        providerTypes.append(P.self)
    }
    
    public mutating func provider<P: Provider>(_ p: P) {
        providers.append(p)
    }
}

extension Services {
    public func multiple<P>(support protocol: P.Type) -> Bool {
        return types(supporting: P.self).count > 1
    }
    
    public func types<P>(supporting protocol: P.Type) -> [ServiceType] {
        return types.filter { service in
            return service.type.supports(protocol: P.self)
        }
    }
    
    public func instances<P>(supporting protocol: P.Type = P.self) -> [ServiceInstance] {
        return instances.filter { service in
            return _instance(service.instance, supports: P.self)
        }
    }
}

private func _instance<P>(_ any: Any, supports protocol: P.Type) -> Bool {
    return any as? P != nil
}
