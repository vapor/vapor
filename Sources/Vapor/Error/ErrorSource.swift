/// A source-code location.
public struct ErrorSource: Sendable {
    /// File in which this location exists.
    public var file: String

    /// Function in which this location exists.
    public var function: String

    /// Line number this location belongs to.
    public var line: UInt

    /// Number of characters into the line this location starts at.
    public var column: UInt

    /// Optional start/end range of the source.
    public var range: Range<UInt>?

    /// Creates a new `SourceLocation`
    public init(
        file: String,
        function: String,
        line: UInt,
        column: UInt,
        range: Range<UInt>? = nil
    ) {
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.range = range
    }
}

extension ErrorSource {
    /// Creates a new `ErrorSource` for the current call site.
    public static func capture(
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column,
        range: Range<UInt>? = nil
    ) -> Self {
        return self.init(
            file: file,
            function: function,
            line: line,
            column: column,
            range: range
        )
    }
}
