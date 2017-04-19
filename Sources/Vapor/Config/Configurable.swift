// MARK: Configurable

extension Config {
    /// Stores all lazily initialized configurable objects.
    internal var configurable: [String: Config.Lazy<Any>] {
        get { return storage["vapor:configurable"] as? [String: Config.Lazy<Any>] ?? [:] }
        set { storage["vapor:configurable"] = newValue }
    }
    
    /// Adds a configurable instance according to the information supplied.
    public func customAddConfigurable<C>(
        instance: C,
        unique: String,
        name: String
    ) {
        let key = "\(unique)-\(name)"
        configurable[key] = { _ in instance }
    }
    
    /// Adds a configurable class according to the information supplied.
    public func customAddConfigurable<C: ConfigInitializable>(
        class: C.Type,
        unique: String,
        name: String
    ) {
        let key = "\(unique)-\(name)"
        configurable[key] = C.lazy()
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
