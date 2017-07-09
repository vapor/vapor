extension Droplet {
    public func client() throws -> ClientFactoryProtocol {
        return try make()
    }
}
