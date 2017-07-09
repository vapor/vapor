extension Droplet {
    /// Send informational and error logs.
    /// Defaults to the console.
    public func log() throws -> LogProtocol {
        return try make()
    }
}
