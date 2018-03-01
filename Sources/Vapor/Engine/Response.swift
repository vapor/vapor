import Dispatch
import Service

public struct HTTPResponse {
    /// The HTTP response status.
    public var status: HTTPResponseStatus

    /// The HTTP version that corresponds to this response.
    public var version: HTTPVersion

    /// The HTTP headers on this response.
    public var headers: HTTPHeaders

    /// The http body
    public var body: HTTPBody?

    /// Creates a new HTTP Request
    public init(
        status: HTTPResponseStatus = .ok,
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPHeaders = .init(),
        body: HTTPBody? = nil
    ) {
        self.status = status
        self.version = version
        self.headers = headers
        self.body = body
    }
}

public final class Response: EphemeralContainer {
    /// See EphemeralWorker.onInit
    public static var onInit: LifecycleHook?

    /// See EphemeralWorker.onDeinit
    public static var onDeinit: LifecycleHook?

    /// Underlying HTTP response.
    public var http: HTTPResponse

    /// This response's worker
    public let superContainer: Container

    /// This response's private container.
    public let privateContainer: SubContainer

    /// Create a new Response
    public init(http: HTTPResponse = HTTPResponse(), using container: Container) {
        self.http = http
        self.superContainer = container
        self.privateContainer = container.subContainer(on: container)
        Response.onInit?(self)
    }

    /// Called when request is deinitializing
    deinit {
        Response.onDeinit?(self)
    }
}

//extension Response: CustomStringConvertible {
//    /// See `CustomStringConvertible.description
//    public var description: String {
//        return http.description
//    }
//}
//
//extension Response: CustomDebugStringConvertible {
//    /// See `CustomDebugStringConvertible.debugDescription`
//    public var debugDescription: String {
//        return http.debugDescription
//    }
//}

extension Response {
    /// The response's event loop container.
    /// note: convenience name for `.superContainer`
    public var worker: Container {
        return superContainer
    }

    /// Container for parsing/serializing content
    public var content: ContentContainer {
        return ContentContainer(container: self, body: http.body!, mediaType: .json/*http.mediaType*/) { body, mediaType in
            self.http.body = body
//            self.http.mediaType = mediaType
        }
    }
}
