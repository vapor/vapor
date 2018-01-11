/// MARK: Vapor Cloud

extension Environment {
    /// An environment for deploying to Vapor Cloud.
    public static var cloud: Environment {
        return .custom(name: "cloud", isRelease: true)
    }
}

extension EngineServerConfig {
    /// Creates server config for use with Vapor Cloud.
    /// Vapor Cloud requires that the port be set to $PORT
    /// and the hostname be 0.0.0.0
    public static func cloud() throws -> EngineServerConfig {
        guard let string = Environment.get("PORT"), let port = UInt16(string) else {
            throw VaporError(identifier: "cloudConfig", reason: "No $PORT environment variable was found.")
        }
        return EngineServerConfig(hostname: "0.0.0.0", port: port)
    }
}

/// MARK: Heroku

extension Environment {
    /// An environment for deploying to Heroku.
    public static var heroku: Environment {
        return .custom(name: "heroku", isRelease: true)
    }
}

extension EngineServerConfig {
    /// Creates server config for use with Heroku.
    /// Heroku requires that the port be set to $PORT
    /// and the hostname be 0.0.0.0
    public static func heroku() throws -> EngineServerConfig {
        return try cloud()
    }
}

