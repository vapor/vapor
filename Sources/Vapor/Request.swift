import Async
import HTTP
import Service

public struct ContentContainer {
    var message: Message
    let container: Container
}

public struct QueryContainer {
    var query: String
    let container: Container
}

public final class Request: EphemeralWorker, ParameterBag {
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

    /// Container for parsing/serializing content
    public var content: ContentContainer

    /// Container for parsing/serializing URI query strings
    public var query: QueryContainer

    /// See ParameterBag.parameters
    public var parameters: [ResolvedParameter]

    /// See Extendable.extend
    public var extend: Extend

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

    /// Create a new Request
    public init(http: HTTPRequest = HTTPRequest(), on worker: Worker, using container: Container) {
        self.http = http
        self.eventLoop = worker.eventLoop
        self.config = container.config
        self.environment = container.environment
        self.services = container.services
        self.content = ContentContainer(message: http, container: eventLoop.container!)
        self.query = QueryContainer(query: http.uri.query!, container: eventLoop.container!)
        self.parameters = []
        self.extend = Extend()
        Request.onInit?(self)
    }

    /// Called when request is deinitializing
    deinit {
        Request.onDeinit?(self)
        // print("Request.deinit")
    }
}

public final class Response: EphemeralWorker {
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

    /// Container for parsing/serializing content
    public var content: ContentContainer

    /// See Extendable.extend
    public var extend: Extend

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
    
    /// Create a new Response
    public init(http: HTTPResponse = HTTPResponse(), on worker: Worker, using container: Container) {
        self.http = http
        self.eventLoop = worker.eventLoop
        self.config = container.config
        self.environment = container.environment
        self.services = container.services
        self.content = ContentContainer(message: http, container: eventLoop.container!)
        self.extend = Extend()
        Response.onInit?(self)
    }


    /// Called when request is deinitializing
    deinit {
        Response.onDeinit?(self)
    }
}
