extension Application {
    public var routes: Routes {
        self.core.routes
    }
    
    public var console: Console {
        get { self.core.console }
        set { self.core.console = newValue }
    }
    
    public var middleware: MiddlewareConfiguration {
        get { self.core.middleware }
        set { self.core.middleware = newValue }
    }
    
    public var commands: CommandConfiguration {
        get { self.core.commands }
        set { self.core.commands = newValue }
    }
    
    public var threadPool: NIOThreadPool {
        self.core.threadPool
    }
    
    public func makeResponder() -> Responder {
        ApplicationResponder(
            routes: self.routes,
            middleware: self.middleware.resolve()
        )
    }
    
    public var fileio: NonBlockingFileIO {
        self.core.fileio
    }
    
    public var allocator: ByteBufferAllocator {
        self.core.allocator
    }
    
    public var server: Server {
        get { self.core.server }
        set { self.core.server = newValue}
    }
    
    public var sessions: Sessions {
        get { self.core.sessions }
        set { self.core.sessions = newValue }
    }
    
    public var running: Running? {
        get { self.core.running.current }
        set { self.core.running.current = newValue }
    }
    
    public var client: Client {
        ApplicationClient(http: self.core.client)
    }
    
    public var directory: DirectoryConfiguration {
        get { self.core.directory }
        set { self.core.directory = newValue }
    }
    
    var core: CoreStorage {
        get { self.userInfo["core"] as! CoreStorage }
        set { self.userInfo["core"] = newValue }
    }
}
