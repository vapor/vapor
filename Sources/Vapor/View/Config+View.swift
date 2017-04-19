extension Config {
    /// Adds a configurable View instance.
    public func addConfigurable<
        View: ViewRenderer
    >(view: View, name: String) {
        customAddConfigurable(instance: view, unique: "view", name: name)
    }
    
    /// Adds a configurable View class.
    public func addConfigurable<
        View: ViewRenderer & ConfigInitializable
    >(view: View.Type, name: String) {
        customAddConfigurable(class: View.self, unique: "view", name: name)
    }
    
    /// Overrides the configurable View with this instance.
    public func override<
        View: ViewRenderer
    >(view: View) {
        customOverride(instance: view, unique: "view")
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
