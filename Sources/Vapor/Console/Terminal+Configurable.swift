import Console

extension Terminal: Service {
    public static var name: String {
        return "terminal"
    }
    
    public convenience init?(_ drop: Droplet) throws {
        try self.init(config: drop.config)
    }
}

extension Terminal: ConfigInitializable {
    public convenience init(config: Config) throws {
        self.init(arguments: config.arguments)
    }
}
