import HTTP
import Service
import Node
import Routing

fileprivate let errorView = ErrorView()

/// Catches errors and converts them into responses
/// which a description of the error.
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
            log.swiftError(error)
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
            return View(bytes: bytes).makeResponse()
        }
        
        let status = Status(error)
        let response = Response(status: status)
        response.json = JSON(error, env: environment)
        return response
    }
}

import JSONs

extension ErrorMiddleware: ServiceType {
    /// See Service.name
    public static var serviceName: String {
        return "error"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [Middleware.self]
    }

    /// See Service.make
    public static func makeService(for container: Container) throws -> ErrorMiddleware? {
        return try .init(container.config.environment, container.make(LogProtocol.self))
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
        
        var json = JSON.object(["error": .bool(true)])
        if let abort = error as? AbortError {
            json["reason"] = .string(abort.reason)
        } else {
            json["reason"] = .string(status.reasonPhrase)
        }
        
        guard env != .production else {
            self = json
            return
        }
        
        if env != .production {
            if let abort = error as? AbortError {
                json["metadata"] = (try? abort.metadata.converted(to: JSON.self)) ?? .null
            }
            
            if let debug = error as? Debuggable {
                json["debugReason"] = .string(debug.reason)
                json["identifier"] = .string(debug.fullIdentifier)
                json["possibleCauses"] = .array(debug.possibleCauses.map { .string($0) })
                json["suggestedFixes"] = .array(debug.suggestedFixes.map { .string($0) })
                json["documentationLinks"] = .array(debug.documentationLinks.map { .string($0) })
                json["stackOverflowQuestions"] = .array(debug.stackOverflowQuestions.map { .string($0) })
                json["gitHubIssues"] = .array(debug.gitHubIssues.map { .string($0) })
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

extension LogProtocol {
    public func swiftError(_ error: Error) {
        if let debuggable = error as? Debuggable {
            self.error(debuggable.loggable)
        } else {
            let type = String(reflecting: Swift.type(of: error))
            self.error("[\(type): \(error)]")
            info("Conform '\(type)' to Debugging.Debuggable to provide more debug information.")
        }
    }
}
