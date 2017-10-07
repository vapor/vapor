/// Capable of serializing a Fluent Query
/// into SQL.
public protocol SQLSerializer {

}

extension SQLSerializer {
    public func makePlaceholder(name: String) -> String {
        return "?"
    }

    public func makeEscapedString(from string: String) -> String {
        return "`\(string)`"
    }
}

