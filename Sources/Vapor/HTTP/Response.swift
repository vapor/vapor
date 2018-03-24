import Dispatch
import Service

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
    public init(http: HTTPResponse = .init(), using container: Container) {
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

public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus: ResponseEncodable {
    /// See `ResponseEncodable.encode(for:)`
    public func encode(for req: Request) throws -> Future<Response> {
        return Future.map(on: req) { Response(http: .init(status: self), using: req) }
    }
}

extension Response: CustomStringConvertible {
    /// See `CustomStringConvertible.description
    public var description: String {
        return http.description
    }
}

extension Response: CustomDebugStringConvertible {
    /// See `CustomDebugStringConvertible.debugDescription`
    public var debugDescription: String {
        return http.debugDescription
    }
}

extension Response {
    /// The response's event loop container.
    /// note: convenience name for `.superContainer`
    public var worker: Container {
        return superContainer
    }

    /// Container for parsing/serializing content
    public var content: ContentContainer {
        return ContentContainer(container: self, body: http.body, mediaType: http.mediaType) { body, mediaType in
            self.http.body = body
            self.http.mediaType = mediaType
        }
    }
    
    public func makeRequest() -> Request {
        return Request(using: superContainer)
    }
}
