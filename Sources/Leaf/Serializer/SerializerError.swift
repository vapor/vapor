/// Errors that can be thrown by the Leaf serializer.
public struct SerializerError: Error {
    public let source: Source
    public let reason: String

    static func unexpectedSyntax(_ syntax: Syntax) -> SerializerError {
        return SerializerError(source: syntax.source, reason: "Unexpected \(syntax.kind.name).")
    }

    static func unknownTag(name: String, source: Source) -> SerializerError {
        return SerializerError(source: source, reason: "Unknown tag `\(name)`.")
    }

    static func invalidNumber(_ data: Context?, source: Source) -> SerializerError {
        let data: Context = data ?? .null
        return SerializerError(source: source, reason: "`\(data)` is not a valid number.")
    }
}
