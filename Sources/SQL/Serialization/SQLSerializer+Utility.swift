extension SQLSerializer {
    /// See SQLSerializer.makePlaceholder(name:)
    public func makePlaceholder(name: String) -> String {
        return "?"
    }

    /// See SQLSerializer.makeEscapedString(from:)
    public func makeEscapedString(from string: String) -> String {
        return "`\(string)`"
    }
}
