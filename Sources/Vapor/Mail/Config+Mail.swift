extension Config {
    /// Adds a configurable Mail instance.
    public mutating func addConfigurable<
        Mail: MailProtocol
    >(mail: Mail, name: String) {
        addConfigurable(instance: mail, unique: "mail", name: name)
    }
    
    /// Adds a configurable Mail class.
    public mutating func addConfigurable<
        Mail: MailProtocol & ConfigInitializable
    >(mail: Mail.Type, name: String) {
        addConfigurable(class: Mail.self, unique: "mail", name: name)
    }
    
    /// Resolves the configured Mail.
    public func resolveMail() throws -> MailProtocol {
        return try resolve(
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
