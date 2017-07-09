import Console

extension Droplet {
    public func commands() throws -> [Command] {
        return try make([Command.self])
    }
}
