import Async

/// Capable of creating instances of registered services.
/// This container makes use of config and environment
/// to determine which service instances are most appropriate to create.
public protocol Context: Worker, Extendable {
    var config: Config { get }
    var environment: Environment { get }
    var services: Services { get }
    var eventLoop: EventLoop { get }
}

/// Wraps a container's values to with codable support
public final class BasicContext: Context, Codable {
    public var extend = Extend()
    
    /// See Container.services
    public let services: Services
    
    /// See Container.config
    public let config: Config
    
    /// See Container.eventLoop
    public let eventLoop: EventLoop
    
    /// See Container.environment
    public let environment: Environment
    
    /// Encodes to nothing
    public func encode(to encoder: Encoder) throws {}
    
    /// Creates a default basic ContainerBox
    public convenience init(from decoder: Decoder) throws {
        self.init()
    }
    
    /// Wraps a container's values
    public static func boxing(_ context: Context) -> BasicContext {
        return BasicContext(
            config: context.config,
            environment: context.environment,
            services: context.services,
            eventLoop: context.eventLoop
        )
    }
    
    public init(
        config: Config = Config(),
        environment: Environment = .detect(),
        services: Services = Services(),
        eventLoop: EventLoop = .default
    ) {
        self.config = config
        self.environment = environment
        self.services = services
        self.eventLoop = eventLoop
    }
}

// MARK: Async

extension EventLoop: Context {
    /// See Container.environment
    public var environment: Environment {
        get {
            return (extend["services:config"] as? Environment) ?? Environment.detect()
        }
        set {
            extend["services:config"] = newValue
        }
    }
    
    /// See Container.services
    public var services: Services {
        get {
            return (extend["services:config"] as? Services) ?? Services()
        }
        set {
            extend["services:config"] = newValue
        }
    }
    
    /// See Container.config
    public var config: Config {
        get {
            return (extend["services:config"] as? Config) ?? Config()
        }
        set {
            extend["services:config"] = newValue
        }
    }
    
    /// Returns itself
    ///
    /// Sets all Context variables with the value of the new Context
    public var context: Context {
        get {
            return self
        }
        set {
            self.environment = newValue.environment
            self.services = newValue.services
            self.config = newValue.config
        }
    }
}
