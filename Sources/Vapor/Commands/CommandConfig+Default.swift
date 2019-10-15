extension CommandConfiguration {
    /// Creates a `CommandConfig` containing all of Vapor's default commands.
    ///
    ///     s.register(CommandConfig.self) { c in
    ///         return try .default(on: c)
    ///     }
    ///
    public static func `default`(on app: Application) throws -> CommandConfiguration {
        var config = CommandConfiguration()
        try config.use(app.make(ServeCommand.self), as: "serve", isDefault: true)
        try config.use(app.make(RoutesCommand.self), as: "routes")
        try config.use(app.make(BootCommand.self), as: "boot")
        return config
    }
}
