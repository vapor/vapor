extension Config {
    /// Vapor's default configuration options.
    ///
    /// Currently this just includes preference for `ConsoleLogger`, but it
    /// may include more things in the future.
    public static func `default`() -> Config {
        var config = Config()
        config.prefer(ConsoleLogger.self, for: Logger.self)
        return config
    }
}
