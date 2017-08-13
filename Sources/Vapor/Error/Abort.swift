import Debugging
import HTTP

/// A basic conformance to `AbortError` for
/// convenient error throwing
public struct Abort: AbortError, Debuggable, Traceable, Helpable {
    public let status: Status
    public let metadata: [String: String]?

    // MARK: Debuggable

    /// See Debuggable.readableName
    public static let readableName = "Abort request error"

    /// See AbortError.reason
    public let reason: String

    /// See Debuggable.identifier
    public let identifier: String

    /// See Debuggable.possibleCauses
    public let possibleCauses: [String]

    /// See Debuggable.possibleCauses
    public let suggestedFixes: [String]

    /// See Debuggable.documentationLinks
    public let documentationLinks: [String]

    /// See Debuggable.stackOverflowQuestions
    public let stackOverflowQuestions: [String]

    /// See Debuggable.gitHubIssues
    public let gitHubIssues: [String]
    
    /// File in which the error was thrown
    public let file: String

    /// Function from which the error was thrown
    public let function: String
    
    /// Line number at which the error was thrown
    public let line: UInt
    
    /// The column at which the error was thrown
    public let column: UInt

    /// The stack trace at which the error was thrown
    public var stackTrace: [String]

    public init(
        _ status: Status,
        metadata: [String: String]? = nil,
        // Debuggable
        reason: String? = nil,
        identifier: String? = nil,
        possibleCauses: [String]? = nil,
        suggestedFixes: [String]? = nil,
        documentationLinks: [String]? = nil,
        stackOverflowQuestions: [String]? = nil,
        gitHubIssues: [String]? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.status = status
        self.metadata = metadata
        self.reason = reason ?? status.reasonPhrase
        self.identifier = identifier ?? "\(status)"
        self.possibleCauses = possibleCauses ?? []
        self.suggestedFixes = suggestedFixes ?? []
        self.documentationLinks = documentationLinks ?? []
        self.stackOverflowQuestions = stackOverflowQuestions ?? []
        self.gitHubIssues = gitHubIssues ?? []
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.stackTrace = Abort.makeStackTrace()
    }
}
