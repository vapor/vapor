extension Config {
    /// Adds a configurable View instance.
    public mutating func addConfigurable<
        View: ViewRenderer
    >(view: View, name: String) {
        addConfigurable(instance: view, unique: "view", name: name)
    }
    
    /// Adds a configurable View class.
    public mutating func addConfigurable<
        View: ViewRenderer & ConfigInitializable
    >(view: View.Type, name: String) {
        addConfigurable(class: View.self, unique: "view", name: name)
    }
    
    /// Resolves the configured View.
    public func resolveView() throws -> ViewRenderer {
        return try resolve(
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
