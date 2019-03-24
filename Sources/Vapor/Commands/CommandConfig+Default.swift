//extension CommandConfig {
//    /// Creates a `CommandConfig` containing all of Vapor's default commands.
//    ///
//    ///     var commandConfig = CommandConfig.default()
//    ///     // add other commands...
//    ///     services.register(commandConfig)
//    ///
//    public static func `default`(on container: Container) throws -> CommandConfig {
//        var config = CommandConfig()
//        try config.use(HTTPServeCommand(server: container.make()), as: "serve", isDefault: true)
//        try config.use(RoutesCommand(router: container.make()), as: "routes")
//        config.use(BootCommand(), as: "boot")
//        return config
//    }
//}
