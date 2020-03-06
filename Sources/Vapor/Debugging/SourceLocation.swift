/// A source-code location.
public struct SourceLocation {
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
    public init(file: String, function: String, line: UInt, column: UInt, range: Range<UInt>?) {
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.range = range
    }
}

extension SourceLocation {
    /// Creates a new `SourceLocation` for the current call site.
    public static func capture(
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column,
        range: Range<UInt>? = nil
    ) -> SourceLocation {
        return SourceLocation(file: file, function: function, line: line, column: column, range: range)
    }
}
