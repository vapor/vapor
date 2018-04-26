extension CommandConfig {
    /// Creates a `CommandConfig` containing all of Vapor's default commands.
    ///
    ///     var commandConfig = CommandConfig.default()
    ///     // add other commands...
    ///     services.register(commandConfig)
    ///
    public static func `default`() -> CommandConfig {
        var config = CommandConfig()
        config.use(ServeCommand.self, as: "serve", isDefault: true)
        config.use(RoutesCommand.self, as: "routes")
        return config
    }
}
