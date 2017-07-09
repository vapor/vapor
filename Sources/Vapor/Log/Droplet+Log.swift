extension Droplet {
    public func log() throws -> LogProtocol {
        return try make()
    }
}
