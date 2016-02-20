import Foundation

#if os(Linux)
    import Glibc
#endif


public class Server {
    
    public static let VERSION = "0.1.9"
    
    /**
        The router driver is responsible
        for returning registered `Route` handlers
        for a given request.
    */
    public var router: RouterDriver
    
    /**
        The `ServerDriver` is responsible
        for handling connections on the desired port.
        This property is constant since it cannot
        be changed after the server has been booted.
    */
    public let driver: ServerDriver
    
    /**
        `Middleware` will be applied in the order
        it is set in this array. 
     
        Make sure to append your custom `Middleware`
        if you don't want to overwrite default behavior.
    */
    public var middleware: [Middleware]

    /**
        Initializes the `Server` with a
        `SocketServer` and `NodeRouter`.
    */
    public convenience init() {
        let driver = SocketServer()
        self.init(driver: driver)
    }
    
    /**
        The work directory of your application is
        the directory in which your Resources, Public, etc
        folders are stored. This is normally `./` if
        you are running Vapor using `.build/xxx/App`
    */
    public static var workDir = "./" {
        didSet {
            if !self.workDir.hasSuffix("/") {
                self.workDir += "/"
            }
        }
    }
    
    /**
        Initialize the `Server` with a custom
        `ServerDriver`
    */
    public init(driver: ServerDriver, router: RouterDriver = Route) {
        self.driver = driver
        self.router = router
        
        self.middleware = [
            SessionMiddleware()
        ]
        
        self.driver.delegate = self
    }

    /**
        Boots the chosen `ServerDriver` and
        runs on the supplied port.
    */
    public func run(port inPort: Int = 80) {
        var port = inPort

        //grab process args
        for argument in Process.arguments {
            if argument.hasPrefix("--workDir=") {
                let workDirString = argument.split("=")[1]
                Server.workDir = workDirString
                print("Work dir override: \(workDirString)")
            } else if argument.hasPrefix("--port=") {
                let portString = argument.split("=")[1]
                if let portInt = Int(portString) {
                    print("Port override: \(portInt)")
                    port = portInt
                }
            }
        }

        do {
            try self.driver.boot(port: port)

            print("Server has started on port \(port)")

            self.loop()
        } catch {
            print("Server start error: \(error)")
        }
    }
    
    
    /**
        Starts an infinite loop to keep the server alive while it
        waits for inbound connections.
    */
    func loop() {
        #if os(Linux)
            while true {
                sleep(1)
            }
        #else
            NSRunLoop.mainRunLoop().run()
        #endif
    }

}

extension Server: ServerDriverDelegate {
    public func serverDriverDidReceiveRequest(request: Request) -> Response {
        var handler: Request -> Response
        
        //check in routes
        if let routerHandler = router.route(request) {
            handler = { req in
                let response: Response
                do {
                    response = try routerHandler(req)
                } catch View.Error.InvalidPath {
                    response = Response(status: .NotFound, text: "View not found")
                } catch {
                    response = Response(error: "Server Error: \(error)")
                }
                
                return response
            }
        } else {
            //check in file system
            let filePath = Server.workDir + "Public" + request.path
            
            let fileManager = NSFileManager.defaultManager()
            var isDir: ObjCBool = false
            
            if fileManager.fileExistsAtPath(filePath, isDirectory: &isDir) {
                //file exists
                if let fileBody = NSData(contentsOfFile: filePath) {
                    var array = [UInt8](count: fileBody.length, repeatedValue: 0)
                    fileBody.getBytes(&array, length: fileBody.length)
                    
                    return Response(status: .OK, data: array, contentType: .Text)
                } else {
                    handler = { _ in
                        return Response(error: "Could not open file.")
                    }
                }
            } else {
                //default not found handler
                handler = { _ in
                    return Response(status: .NotFound, text: "Page not found")
                }
            }
        }
        
        //loop through middlewares in order
        for middleware in self.middleware {
            handler = middleware.handle(handler)
        }
        
        let response = handler(request)
        return response
    }
}
