import HTTP

extension DateMiddleware: ConfigInitializable {
    public convenience init(config: Config) throws {
        self.init()
    }
}

extension FileMiddleware: ConfigInitializable {
    public convenience init(config: Config) throws {
        try self.init(
            publicDir: config.publicDir,
            chunkSize: config.get("file.chunkSize")
        )
    }
}
