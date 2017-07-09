extension Droplet {
    public func cipher() throws -> CipherProtocol {
        return try make()
    }
}
