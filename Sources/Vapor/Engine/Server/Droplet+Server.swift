extension Droplet {
    public func server() throws -> ServerFactoryProtocol {
        return try make()
    }
}
