import Configs

private let configurableKey = "vapor:configurable"
private let overrideKey = "vapor:override"

extension Config {
    
    // MARK: Configurable
    
    internal var configurable: [String: Config.Lazy<Any>] {
        get { return storage[configurableKey] as? [String: Config.Lazy<Any>] ?? [:] }
        set { storage[configurableKey] = newValue }
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
    
    internal var override: [String: Config.Lazy<Any>] {
        get { return storage[overrideKey] as? [String: Config.Lazy<Any>] ?? [:] }
        set { storage[overrideKey] = newValue }
    }
    

    public mutating func override<C>(_ item: C) throws {
        let key = try self.key(for: C.self)
        override[key] = { _ in item }
    }
    
    public mutating func override<C: ConfigInitializable>(_ item: C.Type) throws {
        let key = try self.key(for: C.self)
        override[key] = C.lazy()
    }
    
    // MARK: Resolve
    
    public func resolve<C>(_ c: C.Type) throws -> C? {
        let key = try self.key(for: C.self)
        
        if let override = self.override[key] as? Config.Lazy<C> {
            return try override(self)
        }
        
        guard let chosen = self["droplet", key]?.string else {
            return nil
        }
        let chosenKey = try self.key(for: C.self, name: chosen)
        
        guard let configurable = self.configurable[chosenKey] as? Config.Lazy<C> else {
            throw ConfigError.unavailable(
                value: chosen,
                key: ["log"],
                file: "droplet",
                available: self.configurable.keys.array,
                type: LogProtocol.self
            )
        }
        
        return try configurable(self)
    }
    
    // MARK: Utilities
    
    private func key<C>(for type: C.Type, name: String? = nil) throws -> String {
        let key: String
        
        if type is LogProtocol {
            key = "log"
        } else {
            throw ConfigError.unsupportedType(C.self)
        }
        
        if let name = name {
            return "\(key)-\(name)"
        } else {
            return key
        }
    }
}
