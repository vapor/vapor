extension Config {
    /// Adds a configurable View.
    public func addConfigurable<
        View: ViewRenderer
    >(view: @escaping Config.Lazy<View>, name: String) {
        customAddConfigurable(closure: view, unique: "view", name: name)
    }
    
    /// Resolves the configured View.
    public func resolveView() throws -> ViewRenderer {
        return try customResolve(
            unique: "view",
            file: "droplet",
            keyPath: ["view"],
            as: ViewRenderer.self,
            default: StaticViewRenderer.init
        )
    }
}

extension StaticViewRenderer: ConfigInitializable {
    public convenience init(config: Config) throws {
        self.init(viewsDir: config.viewsDir)
    }
}
