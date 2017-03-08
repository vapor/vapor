import HTTP
import Routing

extension Droplet: Responder {
    /// Returns a response to the given request
    ///
    /// - parameter request: received request
    /// - throws: error if something fails in finding response
    /// - returns: response if possible
    public func respond(to request: Request) -> Response {
        log.info("\(request.method) \(request.uri.path)")
        do {
            return try responder.respond(to: request)
        } catch {
            return errorResponse(with: request, and: error)
        }
    }

    private func errorResponse(with request: Request, and error: Error) -> Response {
        logError(error)
        let status = Status(error)

        if request.accept.prefers("html") {
            return ErrorView.shared.makeResponse(status, status.reasonPhrase)
        }

        let response = Response(status: status)
        if let json = try? JSON(error, env: environment) {
            response.json = json
        } else {
            response.json = [
                "error": true,
                "reason": "unknown"
            ]
        }
        return response
    }

    private func logError(_ error: Error) {
        if let debuggable = error as? Debuggable {
            log.error(debuggable.loggable)
        } else {
            let type = String(reflecting: type(of: error))
            log.error("[\(type): \(error)]")
            log.info("Conform '\(type)' to Debugging.Debuggable to provide more debug information.")
        }
    }
}

extension Status {
    fileprivate init(_ error: Error) {
        if let abort = error as? AbortError {
            self = abort.status
        } else {
            self = .internalServerError
        }
    }
}

extension JSON {
    fileprivate init(_ error: Error, env: Environment) throws {
        let status = Status(error)

        var json = JSON([:])
        try json.set("error", true)

        if let abort = error as? AbortError {
            try json.set("reason", abort.reason)
        } else {
            try json.set("reason", status.reasonPhrase)
        }

        if env != .production {
            if let abort = error as? AbortError {
                try json.set("metadata", abort.metadata)
            }

            if let debug = error as? Debuggable {
                try json.set("debugReason", debug.reason)
                try json.set("identifier", debug.fullIdentifier)
                if !debug.possibleCauses.isEmpty {
                    try json.set("possibleCauses", debug.possibleCauses)
                }
                if !debug.suggestedFixes.isEmpty {
                    try json.set("suggestedFixes", debug.suggestedFixes)
                }
                if !debug.documentationLinks.isEmpty {
                    try json.set("documentationLinks", debug.documentationLinks)
                }
                if !debug.stackOverflowQuestions.isEmpty {
                    try json.set("stackOverflowQuestions", debug.stackOverflowQuestions)
                }
                if !debug.gitHubIssues.isEmpty {
                    try json.set("gitHubIssues", debug.gitHubIssues)
                }
            }
        }

        self = json
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
