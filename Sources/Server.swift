import Foundation

public class Server {
    
    public static let VERSION = "0.1.6"
    
    public var bootstrap = Bootstrap()
    
    public var router: RouterDriver
    public let driver: ServerDriver

    public convenience init() {
        let driver = SocketServer()
        self.init(driver: driver)
    }
    
    public init(driver: ServerDriver) {
        self.driver = driver
        self.router = NodeRouter()
        
        self.driver.delegate = self
    }

    /**
        Registers all routes from the `Route` interface
        into the current `RouterDriver`.
    */
    func registerRoutes() {
        for route in Route.routes {
            self.router.register(route.method, path: route.path) { request in 
                self.bootstrap.request(request)

                let response: Response
                do {
                    response = try route.closure(request: request).response()
                } catch View.Error.InvalidPath {
                    response = Response(status: .NotFound, text: "View not found")
                } catch {
                    response = Response(error: "Server Error: \(error)")
                }
                self.bootstrap.respond(request, response: response)

                return response
            }
        }
    }

    public func run(port inPort: Int = 80) {
        self.registerRoutes()

        var port = inPort

        //grab process args
        for argument in Process.arguments {
            if argument.hasPrefix("--workDir=") {
                let workDirString = argument.split("=")[1]
                Config.workDir = workDirString
            } else if argument.hasPrefix("--port=") {
                let portString = argument.split("=")[1]
                if let portInt = Int(portString) {
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
        
        //check in routes
        if let result = router.route(request) {
            return result(request)
        }
        
        //check in file system
        let filePath = "Public" + request.path
        let fileManager = NSFileManager.defaultManager()
        var isDir: ObjCBool = false
        if fileManager.fileExistsAtPath(filePath, isDirectory: &isDir) {
            if isDir {
                do {
                    let files = try fileManager.contentsOfDirectoryAtPath(filePath)
                    var response = "<h3>\(filePath)</h3></br><table>"
                    response += files.map({ "<tr><td><a href=\"\(request.path)/\($0)\">\($0)</a></td></tr>"}).joinWithSeparator("")
                    response += "</table>"
                    
                    return Response(status: .OK, html: response)
                } catch {
                    //continue to not found
                }
            } else {
                if let fileBody = NSData(contentsOfFile: filePath) {
                    var array = [UInt8](count: fileBody.length, repeatedValue: 0)
                    fileBody.getBytes(&array, length: fileBody.length)
                    return Response(status: .OK, data: array, contentType: .Text)
                    
                }
            }
        }
        
        
        
        return Response(status: .NotFound, text: "Page not found")
    }
}
