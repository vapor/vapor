/// Errors that can be thrown by the Leaf parser.
public struct ParserError: Error {
    public let source: Source
    public let reason: String

    static func expectationFailed(expected: String, got: String, source: Source) -> ParserError {
        return ParserError(source: source, reason: "Expected `\(expected)` got `\(got)`")
    }

    static func unexpectedEOF(source: Source) -> ParserError {
        return ParserError.expectationFailed(expected: "byte", got: "EOF", source: source)
    }
}
