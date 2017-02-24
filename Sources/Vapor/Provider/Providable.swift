import HTTP
import Console
import Cache

public struct Providable {
    /**
        An optional `Server` Type to provide
        to the droplet.
     
        `Server`s are passed as types since
        they are not initialized until the 
        droplet starts.
    */
    public var server: ServerProtocol.Type?

    /**
        An optional `HashDriver` to provide
        to the droplet.
    */
    public var hash: HashProtocol?

    /**
        An optional `CipherProtocol` to provide
        to the droplet.
    */
    public var cipher: CipherProtocol?

    /**
        An optional `ConsoleProtocol` to provide
        to the droplet.
    */
    public var console: ConsoleProtocol?

    /**
        An optional `Log` to provide to the droplet.
    */
    public var log: LogProtocol?

    /**
        An optional `ViewRenderer` to provide to
        the droplet.
    */
    public var view: ViewRenderer?

    /**
         An optional `HTTPClient` add-on used to make
         outgoing web request operations.
     */
    public var client: ClientProtocol.Type?

    /**
        An optional `CacheProtocol` that will be used
        by the droplet for key:value pair storage.
    */
    public var cache: CacheProtocol?

    /**
        An optional `Middleware` that can be applied
        to the droplet if it's name exists in the middleware
        config.
    */
    public var middleware: [String: Middleware]?

    public init(
        server: ServerProtocol.Type? = nil,
        hash: HashProtocol? = nil,
        cipher: CipherProtocol? = nil,
        console: ConsoleProtocol? = nil,
        log: LogProtocol? = nil,
        view: ViewRenderer? = nil,
        client: ClientProtocol.Type? = nil,
        cache: CacheProtocol? = nil,
        middleware: [String: Middleware]? = nil
    ) {
        self.server = server
        self.hash = hash
        self.cipher = cipher
        self.console = console
        self.log = log
        self.view = view
        self.client = client
        self.cache = cache
        self.middleware = middleware
    }
}
