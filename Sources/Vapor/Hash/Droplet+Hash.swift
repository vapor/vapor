extension Droplet {
    public func hash() throws -> HashProtocol {
        return try make()
    }
}
