extension Config {
    public static func `default`() -> Config {
        var config = Config([:])

        try! config.set("droplet.console", "terminal")
        try! config.set("droplet.log", "console")
        try! config.set("droplet.router", "branch")
        try! config.set("droplet.client", "engine")
        try! config.set("droplet.middleware", ["error", "file", "date"])
        try! config.set("droplet.commands", ["serve", "routes", "dump-config", "provider-install"])
        try! config.set("droplet.view", "static")

        return config
    }
}
