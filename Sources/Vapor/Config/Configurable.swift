// MARK: Configurable

extension Config {
    /// Stores all lazily initialized configurable objects.
    internal var configurable: [String: Config.Lazy<Any>] {
        get { return storage["vapor:configurable"] as? [String: Config.Lazy<Any>] ?? [:] }
        set { storage["vapor:configurable"] = newValue }
    }
    
    /// Adds a configurable class according to the information supplied.
    public func customAddConfigurable<C>(
        closure: @escaping Config.Lazy<C>,
        unique: String,
        name: String
    ) {
        let key = "\(unique)-\(name)"
        configurable[key] = closure
    }
}

// MARK: Lazy

extension Config {
    public typealias Lazy<E> = (Config) throws -> (E)
}

extension ConfigInitializable {
    internal static func lazy() -> Config.Lazy<Self> {
        return { c in try Self.init(config: c) }
    }
}
