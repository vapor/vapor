import Async
import Dispatch

/// Represents a tag that has been parsed.
public struct ParsedTag {
    /// Name used for this tag.
    public let name: String

    /// Resolved parameters to this tag.
    public let parameters: [LeafData]

    /// Optional tag body
    public let body: [Syntax]?

    /// Source code location of this parsed tag
    public let source: Source

    /// Queue to complete futures on.
    public let eventLoop: Worker

    /// Creates a new parsed tag struct.
    init(
        name: String,
        parameters: [LeafData],
        body: [Syntax]?,
        source: Source,
        on worker: Worker
    ) {
        self.name = name
        self.parameters = parameters
        self.body = body
        self.source = source
        self.eventLoop = worker.eventLoop
    }
}


extension ParsedTag {
    /// Create a general tag error.
    public func error(reason: String) -> TagError {
        return TagError(
            tag: name,
            source: source,
            reason: reason
        )
    }

    public func requireParameterCount(_ n: Int) throws {
        guard parameters.count == n else {
            throw error(reason: "Invalid parameter count: \(parameters.count)/\(n)")
        }
    }

    public func requireBody() throws -> [Syntax] {
        guard let body = body else {
            throw error(reason: "Missing body")
        }

        return body
    }

    public func requireNoBody() throws {
        guard body == nil else {
            throw error(reason: "Extraneous body")
        }
    }
}
