import HTTP
import Routing

extension RouterError: AbortError {
    public var status: Status { return Abort.notFound.status }
    public var reason: String { return Abort.notFound.reason }
    public var metadata: Node? { return Abort.notFound.metadata }
}

// TODO: Own File
public final class HeadMiddleware: Middleware {
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        guard request.method == .head else { return try next.respond(to: request) }
        /// The HEAD method is identical to GET.
        ///
        /// https://tools.ietf.org/html/rfc2616#section-9.4
        request.method = .get
        let response = try next.respond(to: request)

        /// The server MUST NOT return a message-body in the response for HEAD.
        ///
        /// https://tools.ietf.org/html/rfc2616#section-9.4
        response.body = .data([])
        return response
    }
}

extension Droplet: Responder {
    /// Returns a response to the given request
    ///
    /// - parameter request: received request
    /// - throws: error if something fails in finding response
    /// - returns: response if possible
    public func respond(to request: Request) throws -> Response {
        log.info("\(request.method) \(request.uri.path)")

        // Loop through middlewares in order, then pass result to router responder
        let responder = middleware.chain(to: router)

        let response: Response
        do {
            response = try responder.respond(to: request)

            if response.headers["Content-Type"] == nil && response.status != .notModified {
                log.warning("Response had no 'Content-Type' header.")
            }
        } catch {
            // get status
            let status: Status

            if let abort = error as? AbortError {
                status = abort.status
            } else {
                status = .internalServerError
            }

            if let debuggable = error as? Debuggable {
                log.error(debuggable.loggable)
            } else {
                let type = String(reflecting: type(of: error))
                log.error("[\(type): \(error)]")
                log.info("Conform '\(type)' to Debugging.Debuggable to provide more debug information.")
            }

            if request.accept.prefers("html") {
                return ErrorView.shared.makeResponse(status, status.reasonPhrase)
            } else {
                var json = JSON([:])
                try json.set("error", true)
                if let abort = error as? AbortError {
                    try json.set("reason", abort.reason)
                } else {
                    try json.set("reason", status.reasonPhrase)
                }

                if environment != .production {
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

                let response = Response(status: status)
                response.json = json
                return response
            }
        }

        return response
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
