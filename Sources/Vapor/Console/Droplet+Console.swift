import Console

extension Droplet {
    /// Send output and receive input from the console
    /// using the underlying `ConsoleDriver`.
    public func console() throws -> ConsoleProtocol {
        return try make()
    }
}
