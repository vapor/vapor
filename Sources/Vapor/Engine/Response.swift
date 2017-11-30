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

    /// See EventLoop.queue
    public var queue: DispatchQueue {
        return superContainer.queue
    }

    /// See Container.config
    public var config: Config

    /// See Container.environment
    public var environment: Environment

    /// See Container.services
    public var services: Services

    /// See Container.serviceCache
    public var serviceCache: ServiceCache

    /// See Extendable.extend
    public var extend: Extend

    /// Create a new Response
    public init(http: HTTPResponse = HTTPResponse(), using container: Container) {
        self.http = http
        self.superContainer = container
        self.config = container.config
        self.environment = container.environment
        self.services = container.services
        self.serviceCache = .init()
        self.extend = Extend()
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
    public var eventLoop: Container {
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
