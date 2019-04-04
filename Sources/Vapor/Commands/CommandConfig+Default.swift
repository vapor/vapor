extension CommandConfig {
    /// Creates a `CommandConfig` containing all of Vapor's default commands.
    ///
    ///     s.register(CommandConfig.self) { c in
    ///         return try .default(on: c)
    ///     }
    ///
    public static func `default`(on c: Container) throws -> CommandConfig {
        var config = CommandConfig()
        try config.use(c.make(ServeCommand.self), as: "serve", isDefault: true)
        try config.use(c.make(RoutesCommand.self), as: "routes")
        try config.use(c.make(BootCommand.self), as: "boot")
        return config
    }
}
