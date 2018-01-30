import Async
import Dispatch
import HTTP
import Routing
import Service
import Foundation

public final class Request: ParameterContainer {
    /// Underlying HTTP request.
    public var http: HTTPRequest

    /// This request's parent container.
    public let superContainer: Container

    /// This request's private container.
    public let privateContainer: SubContainer

    /// Holds parameters for routing
    public var parameters: Parameters
    
    /// True if this request has active connections
    internal var hasActiveConnections: Bool

    /// Create a new Request
    public init(http: HTTPRequest = HTTPRequest(), using container: Container) {
        self.http = http
        self.superContainer = container
        self.privateContainer = container.subContainer(on: container.eventLoop)
        self.parameters = []
        hasActiveConnections = false
    }

    /// Called when the request deinitializes
    deinit {
        if hasActiveConnections {
            try! privateContainer.releaseCachedConnections()
        }
    }
}

extension Request: CustomStringConvertible {
    /// See `CustomStringConvertible.description
    public var description: String {
        return http.description
    }
}

extension Request: CustomDebugStringConvertible {
    /// See `CustomDebugStringConvertible.debugDescription`
    public var debugDescription: String {
        return http.debugDescription
    }
}

/// Conform to container by pointing to super container.
extension Request: SubContainer { }

extension Request {
    /// Container for parsing/serializing URI query strings
    public var query: QueryContainer {
        return QueryContainer(query: http.uri.query ?? "", container: self)
    }

    /// Container for parsing/serializing content
    public var content: ContentContainer {
        return ContentContainer(container: self, body: http.body, mediaType: http.mediaType) { body, mediaType in
            self.http.body = body
            self.http.mediaType = mediaType
        }
    }
}

extension Request {
    /// Make an instance of the provided interface for this Request.
    public func make<T>(_ interface: T.Type = T.self) throws -> T {
        return try make(T.self, for: Request.self)
    }
}

extension Request: DatabaseConnectable {
    /// See DatabaseConnectable.connect
    public func connect<D>(to database: DatabaseIdentifier<D>?) -> Future<D.Connection> {
        guard let database = database else {
            fatalError("Model.defaultDatabase required to use request as worker.")
        }
        hasActiveConnections = true
        return privateContainer.requestCachedConnection(to: database)
    }
}
