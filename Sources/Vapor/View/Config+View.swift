extension StaticViewRenderer: ConfigInitializable {
    public convenience init(config: Config) throws {
        self.init(viewsDir: config.viewsDir)
    }
}
