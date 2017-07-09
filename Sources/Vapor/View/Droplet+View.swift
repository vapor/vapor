extension Droplet {
    public func view() throws -> ViewRenderer {
        return try make()
    }
}
