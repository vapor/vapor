public final class Response: EphemeralContainer {
    /// See EphemeralWorker.onInit
    public static var onInit: LifecycleHook?

    /// See EphemeralWorker.onDeinit
    public static var onDeinit: LifecycleHook?

    /// This message's event loop.
    ///
    /// All async tasks (such as completing or awaiting futures)
    /// must be performed on this queue.
    ///
    /// Make sure not to block this queue as it will
    /// block all other requests on the queue.
    public var eventLoop: EventLoop

    /// Underlying HTTP response.
    public var http: HTTPResponse

    /// See Container.config
    public var config: Config

    /// See Container.environment
    public var environment: Environment

    /// See Container.services
    public var services: Services

    /// See Container.serviceCache
    public var serviceCache: ServiceCache {
        return eventLoop.serviceCache
    }

    /// Container for parsing/serializing content
    public var content: ContentContainer!

    /// See Extendable.extend
    public var extend: Extend


    /// Create a new Response
    public init(http: HTTPResponse = HTTPResponse(), on worker: Worker, using container: Container) {
        self.http = http
        self.eventLoop = worker.eventLoop
        self.config = container.config
        self.environment = container.environment
        self.services = container.services
        self.extend = Extend()
        self.content = ContentContainer(message: self)
        Response.onInit?(self)
    }


    /// Called when request is deinitializing
    deinit {
        Response.onDeinit?(self)
    }
}
