import Console

extension Droplet {
    public func console() throws -> ConsoleProtocol {
        return try make()
    }
}
