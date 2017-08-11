extension Droplet {
    /// Implemented by your email client
    public func mail() throws -> MailProtocol {
        return try make()
    }
}
