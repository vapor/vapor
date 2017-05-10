extension Config {
    /// Adds a configurable Mail.
    public func addConfigurable<
        Mail: MailProtocol
    >(mail: @escaping Config.Lazy<Mail>, name: String) {
        customAddConfigurable(closure: mail, unique: "mail", name: name)
    }
    
    /// Resolves the configured Mail.
    public func resolveMail() throws -> MailProtocol {
        return try customResolve(
            unique: "mail",
            file: "droplet",
            keyPath: ["mail"],
            as: MailProtocol.self,
            default: UnimplementedMailer.init
        )
    }
}

extension UnimplementedMailer: ConfigInitializable {
    public convenience init(config: Config) throws {
        self.init()
    }
}
