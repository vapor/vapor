import HTTP
import Node
import Debugging

/// A basic conformance to `AbortError` for
/// convenient error throwing
public struct Abort: AbortError, Debuggable {
    public let status: Status
    public let metadata: Node?

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


    public init(
        _ status: Status,
        metadata: Node? = nil,
        // Debuggable
        reason: String? = nil,
        identifier: String? = nil,
        possibleCauses: [String]? = nil,
        suggestedFixes: [String]? = nil,
        documentationLinks: [String]? = nil,
        stackOverflowQuestions: [String]? = nil,
        gitHubIssues: [String]? = nil
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
    }

    // most common
    public static let badRequest = Abort(.badRequest)
    public static let unauthorized = Abort(.unauthorized)
    public static let notFound = Abort(.notFound)
    public static let serverError = Abort(.internalServerError)
}
