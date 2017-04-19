extension Config {
    internal var override: [String: Any] {
        get { return storage["vapor:override"] as? [String: Any] ?? [:] }
        set { storage["vapor:override"] = newValue }
    }
    
    /// Overrides an instance with the supplied information
    /// for this config.
    public mutating func customOverride<C>(instance: C, unique: String) {
        override[unique] = instance
    }
}
