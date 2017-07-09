import Console

extension Droplet {
    /// Available Commands to use when starting
    /// the droplet.
    public func commands() throws -> [Command] {
        return try make([Command.self])
    }
}
