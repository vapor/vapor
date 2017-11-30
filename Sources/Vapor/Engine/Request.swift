import Async
import HTTP
import Routing
import Service

public final class Request: EphemeralContainer, ParameterBag {
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

    /// Underlying HTTP request.
    public var http: HTTPRequest

    /// Container for parsing/serializing URI query strings
    public var query: QueryContainer

    /// See ParameterBag.parameters
    public var parameters: [ResolvedParameter]
    
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

    /// Create a new Request
    public init(http: HTTPRequest = HTTPRequest(), on worker: Worker, using container: Container) {
        self.http = http
        self.eventLoop = worker.eventLoop
        self.config = container.config
        self.environment = container.environment
        self.services = container.services
        self.query = QueryContainer(query: http.uri.query ?? "", container: container)
        self.parameters = []
        self.extend = Extend()
        self.content = ContentContainer(message: self)
        Request.onInit?(self)
    }

    /// Called when request is deinitializing
    deinit {
        Request.onDeinit?(self)
        // print("Request.deinit")
    }
}

extension Request {
    /// Make an instance of the provided interface for this Request.
    public func make<T>(_ interface: T.Type) throws -> T {
        return try make(T.self, for: Request.self)
    }
}
