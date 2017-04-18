import Configs
import Console
import Cache
import HTTP
import Sessions

private let configurableKey = "vapor:configurable"
private let overrideKey = "vapor:override"

extension Config {
    
    // MARK: Configurable
    
    internal var configurable: [String: Config.Lazy<Any>] {
        get { return storage[configurableKey] as? [String: Config.Lazy<Any>] ?? [:] }
        set { storage[configurableKey] = newValue }
    }
    
    mutating func addConfigurable<C>(_ item: @escaping Config.Lazy<C>, name: String) throws {
        let key = try self.key(for: C.self, name: name)
        configurable[key] = item
    }
    
    public mutating func addConfigurable<C>(_ item: C, name: String) throws {
        let key = try self.key(for: C.self, name: name)
        configurable[key] = { _ in item }
    }
    
    public mutating func addConfigurable<C: ConfigInitializable>(_ item: C.Type, name: String) throws {
        let key = try self.key(for: C.self, name: name)
        configurable[key] = C.lazy()
    }
    
    // MARK: Override
    
    internal var override: [String: Any] {
        get { return storage[overrideKey] as? [String: Any] ?? [:] }
        set { storage[overrideKey] = newValue }
    }
    
    public mutating func addOverride<C>(_ item: C) throws {
        let key = try self.key(for: C.self)
        override[key] = item
    }
    
    public mutating func addOverride(middleware: [Middleware]) throws {
        let key = try self.key(for: Middleware.self)
        // middleware array needs to be casted to pure [Middleware]
        override[key] = middleware
    }
    
    // MARK: Resolve
    
    public func resolve<C>(_ c: C.Type) throws -> C {
        let key = try self.key(for: C.self)
        
        if let override = self.override[key] as? C {
            return override
        }

        guard let chosen = self["droplet", key]?.string else {
            return try defaultItem(for: C.self)
        }
        
        let chosenKey = try self.key(for: C.self, name: chosen)
        
        guard
            let configurable = self.configurable[chosenKey],
            let c = try configurable(self) as? C
        else {
            throw ConfigError.unavailable(
                value: chosen,
                key: [key],
                file: "droplet",
                available: self.configurable.keys.available(for: key),
                type: C.self
            )
        }
        
        return c
    }
    
    public func resolveArray<C>(_ c: C.Type) throws -> [C] {
        let key = try self.key(for: C.self)
        
        if let override = self.override[key] as? [C] {
            return override
        }
        
        guard let chosen = self["droplet", key]?.array?.flatMap({ $0.string }) else {
            return try defaultItem(for: [C].self)
        }
        
        let configurables: [C] = try chosen.map { name in
            let chosenKey = try self.key(for: C.self, name: name)
            
            guard
                let configurable = self.configurable[chosenKey],
                let c = try configurable(self) as? C
            else {
                throw ConfigError.unavailable(
                    value: name,
                    key: [key],
                    file: "droplet",
                    available: self.configurable.keys.available(for: key),
                    type: C.self
                )
            }
            
            return c
        }

        return configurables
    }
    
    // MARK: Default
    
    internal func defaultItem<C>(for type: C.Type) throws -> C {
        let item: Any
        
        switch type {
        case is LogProtocol.Type, LogProtocol.self:
            let console = try resolve(ConsoleProtocol.self)
            item = ConsoleLogger(console)
        case is ServerFactoryProtocol.Type, ServerFactoryProtocol.self:
            item = ServerFactory<EngineServer>()
        case is ClientFactoryProtocol.Type, ClientFactoryProtocol.self:
            item = ClientFactory<EngineClient>()
        case is HashProtocol.Type, HashProtocol.self:
            item = CryptoHasher(hash: .sha1, encoding: .hex)
        case is CipherProtocol.Type, CipherProtocol.self:
            item = CryptoCipher(
                method: .aes256(.cbc),
                defaultKey: Bytes(repeating: 0, count: 16)
            )
        case is ConsoleProtocol.Type, ConsoleProtocol.self:
            item = Terminal(arguments: arguments)
        case is ViewRenderer.Type, ViewRenderer.self:
            item = StaticViewRenderer(viewsDir: viewsDir)
        case is CacheProtocol.Type, CacheProtocol.self:
            item = MemoryCache()
        case is MailProtocol.Type, MailProtocol.self:
            item = UnimplementedMailer()
        case is Array<Middleware>.Type, Array<Middleware>.self:
            let log = try resolve(LogProtocol.self)
            item = [
                ErrorMiddleware(environment, log),
                DateMiddleware(),
                FileMiddleware(publicDir: publicDir)
            ]
        default:
            throw ConfigError.unsupportedType(C.self)
        }
        
        guard let c = item as? C else {
            throw ConfigError.unsupportedType(C.self)
        }
        
        return c
    }
    
    // MARK: Utilities
    
    private func key<C>(for type: C.Type, name: String? = nil) throws -> String {
        let key: String
        
        switch type {
        case is LogProtocol.Type, LogProtocol.self:
            key = "log"
        case is ServerFactoryProtocol.Type, ServerFactoryProtocol.self:
            key = "server"
        case is ClientFactoryProtocol.Type, ClientFactoryProtocol.self:
            key = "client"
        case is HashProtocol.Type, HashProtocol.self:
            key = "hash"
        case is CipherProtocol.Type, CipherProtocol.self:
            key = "cipher"
        case is ConsoleProtocol.Type, ConsoleProtocol.self:
            key = "console"
        case is ViewRenderer.Type, ViewRenderer.self:
            key = "view"
        case is CacheProtocol.Type, CacheProtocol.self:
            key = "cache"
        case is MailProtocol.Type, MailProtocol.self:
            key = "mail"
        case is Middleware.Type, Middleware.self, is Array<Middleware>.Type, Array<Middleware>.self:
            key = "middleware"
        default:
            throw ConfigError.unsupportedType(C.self)
        }
        
        if let name = name {
            return "\(key)-\(name)"
        } else {
            return key
        }
    }
    
    // MARK: Directories
    
    /// The work directory of your droplet is
    /// the directory in which your Resources, Public, etc
    /// folders are stored. This is normally `./` if
    /// you are running Vapor using `.build/xxx/app`
    public var workDir: String {
        var workDir = self["droplet", "workDir"]?.string
            ?? Config.workingDirectory(from: arguments)
        workDir = workDir.finished(with: "/")
        return workDir
    }
    
    /// Resources directory relative to workDir
    public var resourcesDir: String {
        var resourcesDir = self["droplet", "resourcesDir"]?.string
            ?? workDir + "Resources"
        resourcesDir = resourcesDir.finished(with: "/")
        return resourcesDir
    }

    /// Views directory relative to the
    /// resources directory.
    public var viewsDir: String {
        var viewsDir = self["droplet", "viewsDir"]?.string
            ?? workDir + "Views"
        viewsDir = viewsDir.finished(with: "/")
        return viewsDir
    }
    
    public var localizationDir: String {
        var localizationDir = self["droplet", "localizationDir"]?.string
            ?? workDir + "Localization"
        localizationDir = localizationDir.finished(with: "/")
        return localizationDir
    }
    
    public var publicDir: String {
        var publicDir = self["droplet", "publicDir"]?.string
            ?? workDir + "Public"
        publicDir = publicDir.finished(with: "/")
        return publicDir
    }
}

// MARK: Lazy

extension Config {
    internal typealias Lazy<E> = (Config) throws -> (E)
}

extension ConfigInitializable {
    internal static func lazy() -> Config.Lazy<Self> {
        return { c in try Self.init(config: c) }
    }
}

// MARK: Utilities

fileprivate func ~=<A, B>(pattern: A.Type, value: B.Type) -> Bool {
    return A.self == B.self
}

extension Sequence where Iterator.Element == String {
    fileprivate func available(for key: String) -> [String] {
        return array
            .filter { $0.hasPrefix(key) }
            .map { $0.replacingOccurrences(of: "\(key)-", with: "") }
    }
}
