import Async
import Dispatch
//import HTTP
import Routing
import Service
import Foundation

public typealias HTTPBody = NIO.IOData

public struct HTTPRequest {
    /// The HTTP method for this request.
    public var method: HTTPMethod

    /// The URI used on this request.
    public var uri: String

    /// The version for this HTTP request.
    public var version: HTTPVersion

    /// The header fields for this HTTP request.
    public var headers: HTTPHeaders

    /// The http body
    public var body: HTTPBody?

    /// Creates a new HTTP Request
    public init(
        method: HTTPMethod = .GET,
        uri: String = "/",
        version: HTTPVersion = .init(major: 1, minor: 0),
        headers: HTTPHeaders = .init(),
        body: IOData? = nil
    ) {
        self.method = method
        self.uri = uri
        self.version = version
        self.headers = headers
        self.body = body
    }
}

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
            try! releaseCachedConnections()
        }
    }
}

//extension Request: CustomStringConvertible {
//    /// See `CustomStringConvertible.description
//    public var description: String {
//        return http.description
//    }
//}
//
//extension Request: CustomDebugStringConvertible {
//    /// See `CustomDebugStringConvertible.debugDescription`
//    public var debugDescription: String {
//        return http.debugDescription
//    }
//}

/// Conform to container by pointing to super container.
extension Request: SubContainer { }

extension Request {
//    /// Container for parsing/serializing URI query strings
//    public var query: QueryContainer {
//        return QueryContainer(query: http.uri.query ?? "", container: self)
//    }

    /// Container for parsing/serializing content
    public var content: ContentContainer {
        return ContentContainer(container: self, body: http.body!, mediaType: .json /* http.mediaType */) { body, mediaType in
            self.http.body = body
            // self.http.mediaType = mediaType
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
            let error = VaporError(
                identifier: "defaultDB",
                reason: "Model.defaultDatabase required to use request as worker.",
                suggestedFixes: [
                    "Ensure you are using the 'model' label when registering this model to your migration config (if it is a migration): migrations.add(model: ..., database: ...).",
                    "If the model you are using is not a migration, set the static defaultDatabase property manually in your app's configuration section.",
                    "Use req.withPooledConnection(to: ...) { ... } instead."
                ],
                source: .capture()
            )
            return Future(error: error)
        }
        hasActiveConnections = true
        return requestCachedConnection(to: database)
    }
}
