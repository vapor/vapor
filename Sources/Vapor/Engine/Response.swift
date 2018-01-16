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
    
    /// See Message.version
    public var version: HTTPVersion {
        get {
            return http.version
        }
        set {
            http.version = newValue
        }
    }
    
    /// HTTP response status code.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/status/)
    public var status: HTTPStatus {
        get {
            return http.status
        }
        set {
            http.status = newValue
        }
    }
    
    /// See Message.headers
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/headers/)
    public var headers: HTTPHeaders {
        get {
            return http.headers
        }
        set {
            http.headers = newValue
        }
    }
    
    /// See Message.body
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/body/)
    public var body: HTTPBody {
        get {
            return http.body
        }
        set {
            http.body = newValue
        }
    }

    /// Create a new Response
    public init(http: HTTPResponse = HTTPResponse(), using container: Container) {
        self.http = http
        self.superContainer = container
        self.privateContainer = container.subContainer(on: container.eventLoop)
        Response.onInit?(self)
    }


    /// Called when request is deinitializing
    deinit {
        Response.onDeinit?(self)
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
}
