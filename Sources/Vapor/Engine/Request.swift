import Async
import Dispatch
import HTTP
import Routing
import Service

public final class Request: EphemeralContainer, ParameterContainer {
    /// See EphemeralWorker.onInit
    public static var onInit: LifecycleHook?

    /// See EphemeralWorker.onDeinit
    public static var onDeinit: LifecycleHook?

    /// Underlying HTTP request.
    public var http: HTTPRequest

    /// This response's worker
    public let superContainer: Container

    /// See Worker.queue
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

    /// Holds parameters for routing
    public var parameters: Parameters

    /// See Extendable.extend
    public var extend: Extend
    
    /// HTTP requests have a method, like GET or POST
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/method/)
    public var method: HTTPMethod {
        get {
            return http.method
        }
        set {
            http.method = newValue
        }
    }
    
    /// This is usually just a path like `/foo` but
    /// may be a full URI in the case of a proxy
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/uri/)
    public var uri: URI {
        get {
            return http.uri
        }
        set {
            http.uri = newValue
        }
    }
    
    /// See `Message.version`
    public var version: HTTPVersion {
        get {
            return http.version
        }
        set {
            http.version = newValue
        }
    }
    
    /// See `Message.headers`
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
    
    /// See `Message.body`
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

    /// Create a new Request
    public init(http: HTTPRequest = HTTPRequest(), using container: Container) {
        self.http = http
        self.superContainer = container
        self.config = container.config
        self.environment = container.environment
        self.services = container.services
        self.serviceCache = .init()
        self.extend = Extend()
        self.parameters = []
        Request.onInit?(self)
    }

    /// Called when request is deinitializing
    deinit {
        Request.onDeinit?(self)
    }
}

extension Request {
    /// The request's event loop container.
    /// note: convenience name for `.superContainer`
    public var worker: Container {
        return superContainer
    }

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
    public func make<T>(_ interface: T.Type) throws -> T {
        return try make(T.self, for: Request.self)
    }
}
