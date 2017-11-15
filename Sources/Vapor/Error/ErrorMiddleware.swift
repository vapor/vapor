import HTTP

fileprivate let errorView = ErrorView()

/// Catches errors and converts them into responses
/// with a description of the error.
public final class ErrorMiddleware: Middleware {
    let log: LogProtocol
    let environment: Environment
    public init(_ environment: Environment, _ log: LogProtocol) {
        self.log = log
        self.environment = environment
    }
    
    public func respond(to req: Request, chainingTo next: Responder) throws -> Response {
        do {
            return try next.respond(to: req)
        } catch {
            log.error(error)
            return make(with: req, for: error)
        }
    }
    
    public func make(with req: Request, for error: Error) -> Response {
        guard !req.accept.prefers("html") else {
            let status: Status = Status(error)
            let bytes = errorView.render(
                code: status.statusCode,
                message: status.reasonPhrase
            )
            let res = View(bytes: bytes).makeResponse()
            res.status = status
            return res
        }
        
        let status = Status(error)
        let response = Response(status: status)
        response.json = JSON(error, env: environment)
        return response
    }
}

extension ErrorMiddleware: ConfigInitializable {
    public convenience init(config: Config) throws {
        let log = try config.resolveLog()
        self.init(config.environment, log)
    }
}

extension Status {
    internal init(_ error: Error) {
        if let abort = error as? AbortError {
            self = abort.status
        } else {
            self = .internalServerError
        }
    }
}


extension JSON {
    fileprivate init(_ error: Error, env: Environment) {
        let status = Status(error)
        
        var json = JSON(["error": true])
        if let abort = error as? AbortError {
            json.set("reason", abort.reason)
        } else {
            json.set("reason", status.reasonPhrase)
        }
        
        guard env != .production else {
            self = json
            return
        }
        
        if let abort = error as? AbortError {
            json.set("metadata", abort.metadata)
        }

        if let debug = error as? Debuggable {
            json.set("debugReason", debug.reason)
            json.set("identifier", debug.fullIdentifier)
            json.set("possibleCauses", debug.possibleCauses)
            json.set("suggestedFixes", debug.suggestedFixes)
            json.set("documentationLinks", debug.documentationLinks)
            json.set("stackOverflowQuestions", debug.stackOverflowQuestions)
            json.set("gitHubIssues", debug.gitHubIssues)
        }
        
        self = json
    }
}

extension StructuredDataWrapper {
    fileprivate mutating func set(_ key: String, _ closure: (Context?) throws -> Node) rethrows {
        let node = try closure(context)
        set(key, node)
    }
    
    fileprivate mutating func set(_ key: String, _ value: String?) {
        guard let value = value, !value.isEmpty else { return }
        set(key, .string(value))
    }
    
    fileprivate mutating func set(_ key: String, _ node: Node?) {
        guard let node = node else { return }
        self[key] = Self(node, context)
    }
    
    fileprivate mutating func set(_ key: String, _ array: [String]?) {
        guard let array = array?.map(StructuredData.string).map(Self.init), !array.isEmpty else { return }
        self[key] = .array(array)
    }
}

extension StructuredDataWrapper {
    // TODO: I expected this, maybe put in node
    init(_ node: Node, _ context: Context) {
        self.init(node: node.wrapped, in: context)
    }
}

extension Debuggable {
    var loggable: String {
        var print: [String] = []
        
        print.append("\(Self.readableName): \(reason)")
        print.append("Identifier: \(fullIdentifier)")
        
        if !possibleCauses.isEmpty {
            print.append("Possible Causes: \(possibleCauses.commaSeparated)")
        }
        
        if !suggestedFixes.isEmpty {
            print.append("Suggested Fixes: \(suggestedFixes.commaSeparated)")
        }
        
        if !documentationLinks.isEmpty {
            print.append("Documentation Links: \(documentationLinks.commaSeparated)")
        }
        
        if !stackOverflowQuestions.isEmpty {
            print.append("Stack Overflow Questions: \(stackOverflowQuestions.commaSeparated)")
        }
        
        if !gitHubIssues.isEmpty {
            print.append("GitHub Issues: \(gitHubIssues.commaSeparated)")
        }
        
        return print.map { "[\($0)]" }.joined(separator: " ")
    }
}

extension Sequence where Iterator.Element == String {
    var commaSeparated: String {
        return joined(separator: ", ")
    }
}


extension RouterError: AbortError {
    public var status: Status { return Abort.notFound.status }
    public var reason: String { return Abort.notFound.reason }
    public var metadata: Node? { return Abort.notFound.metadata }
}

extension LogProtocol {
    public func error(_ error: Error) {
        if let debuggable = error as? Debuggable {
            self.error(debuggable.loggable)
        } else {
            let type = String(reflecting: Swift.type(of: error))
            self.error("[\(type): \(error)]")
            info("Conform '\(type)' to Debugging.Debuggable to provide more debug information.")
        }
    }
}
